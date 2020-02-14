# MonitorFtracenumabalance.pm
package MMTests::MonitorFtracenumabalance;
use MMTests::MonitorFtrace;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

# Tracepoint events
use constant TASK_MIGRATE_STICK_NOCPU		=> 1;
use constant TASK_MIGRATE_STICK_IDLEFAIL	=> 2;
use constant TASK_MIGRATE_STICK_SWAPFAIL	=> 3;
use constant TASK_MIGRATE_SWAP			=> 4;
use constant TASK_MIGRATE_SWAP_LOCAL		=> 5;
use constant TASK_MIGRATE_SWAP_GROUP		=> 6;
use constant TASK_MIGRATE_IDLE			=> 7;
use constant TASK_MIGRATE_IDLE_LOCAL		=> 8;
use constant TASK_MIGRATE_RETRY			=> 9;
use constant TASK_MIGRATE_RETRY_SUCCESS		=> 10;
use constant TASK_MIGRATE_RETRY_FAIL		=> 11;
use constant LOAD_BALANCE_CROSS_NUMA		=> 12;
use constant EVENT_UNKNOWN			=> 13;

# Defaults for dynamically discovered regex's
my $regex_sched_stick_numa_default = 'src_pid=([0-9]*) src_tgid=([0-9]*) src_ngid=([0-9]*) src_cpu=([0-9]*) src_nid=([0-9]*) dst_pid=([0-9]*) dst_tgid=([0-9]*) dst_ngid=([0-9]*) dst_cpu=([-0-9]*) dst_nid=([-0-9]*)';
my $regex_sched_move_numa_default = 'pid=([0-9]*) tgid=([0-9]*) ngid=([0-9]*) src_cpu=([0-9]*) src_nid=([0-9]*) dst_cpu=([0-9]*) dst_nid=([0-9])';
my $regex_sched_swap_numa_default = 'src_pid=([0-9]*) src_tgid=([0-9]*) src_ngid=([0-9]*) src_cpu=([0-9]*) src_nid=([0-9]*) dst_pid=([0-9]*) dst_tgid=([0-9]*) dst_ngid=([0-9]*) dst_cpu=([0-9]*) dst_nid=([0-9]*)';
my $regex_sched_move_task_default = 'pid=([0-9]*) tgid=([0-9]*) ngid=([0-9]*) src_cpu=([0-9]*) src_nid=([0-9]*) dst_cpu=([0-9]*) dst_nid=([0-9])';
my $regex_sched_migrate_task_default = 'comm=([a-zA-Z0-9-._\[\]\/\(\): ]*) pid=([0-9]*) prio=([0-9]*) orig_cpu=([0-9]*) dest_cpu=([0-9]*)';

# Dynamically discovered regex
my $regex_sched_stick_numa;
my $regex_sched_move_numa;
my $regex_sched_swap_numa;
my $regex_sched_move_task;
my $regex_sched_migrate_task;

my @_fieldIndexMap;
$_fieldIndexMap[TASK_MIGRATE_STICK_NOCPU]	= "task_migrate_stick_nocpu";
$_fieldIndexMap[TASK_MIGRATE_STICK_IDLEFAIL]	= "task_migrate_stick_idlefail";
$_fieldIndexMap[TASK_MIGRATE_STICK_SWAPFAIL]	= "task_migrate_stick_swapfail";
$_fieldIndexMap[TASK_MIGRATE_SWAP]		= "task_migrate_swap";
$_fieldIndexMap[TASK_MIGRATE_SWAP_LOCAL]	= "task_migrate_swap_local";
$_fieldIndexMap[TASK_MIGRATE_SWAP_GROUP]	= "task_migrate_swap_group";
$_fieldIndexMap[TASK_MIGRATE_IDLE]		= "task_migrate_idle";
$_fieldIndexMap[TASK_MIGRATE_IDLE_LOCAL]	= "task_migrate_idle_local";
$_fieldIndexMap[TASK_MIGRATE_RETRY]		= "task_migrate_retry";
$_fieldIndexMap[TASK_MIGRATE_RETRY_SUCCESS]	= "task_migrate_retry_success";
$_fieldIndexMap[TASK_MIGRATE_RETRY_FAIL]	= "task_migrate_retry_fail";
$_fieldIndexMap[LOAD_BALANCE_CROSS_NUMA]	= "load_balance_cross_numa";
$_fieldIndexMap[EVENT_UNKNOWN]			= "event_unknown";

my %_fieldNameMap = (
	"task_migrate_stick_nocpu"		=> "Migrate failed no CPU",
	"task_migrate_stick_idlefail"		=> "Migrate failed move to   idle",
	"task_migrate_stick_swapfail"		=> "Migrate failed swap task fail",
	"task_migrate_swap"			=> "Task Migrated swapped",
	"task_migrate_swap_local"		=> "Task Migrated swapped local NID",
	"task_migrate_swap_group"		=> "Task Migrated swapped within group",
	"task_migrate_idle"			=> "Task Migrated idle CPU",
	"task_migrate_idle_local"		=> "Task Migrated idle CPU local NID",
	"task_migrate_retry"			=> "Task Migrate retry",
	"task_migrate_retry_success"		=> "Task Migrate retry success",
	"task_migrate_retry_fail"		=> "Task Migrate retry failed",
	"load_balance_cross_numa"		=> "Load Balance cross NUMA",
	"event_unknown"				=> "Unrecognised events",
);

my %task_migrated;
my %cpu_nid;

sub ftraceInit {
	my ($self, $reportDir, $testBenchmark, $subHeading) = @_;
	$regex_sched_move_task = $self->generate_traceevent_regex(
		"sched/sched_move_task",
		$regex_sched_move_task_default,
		"pid", "tgid", "ngid", "src_cpu", "src_nid", "dst_cpu", "dst_nid");
	$regex_sched_stick_numa = $self->generate_traceevent_regex(
		"sched/sched_stick_numa",
		$regex_sched_stick_numa_default,
		"src_pid", "src_tgid", "src_ngid", "src_cpu", "src_nid", "dst_pid", "dst_tgid", "dst_ngid", "dst_cpu", "dst_nid");
	$regex_sched_move_numa = $self->generate_traceevent_regex(
		"sched/sched_move_numa",
		$regex_sched_move_numa_default,
		"pid", "tgid", "ngid", "src_cpu", "src_nid", "dst_cpu", "dst_nid");
	$regex_sched_swap_numa = $self->generate_traceevent_regex(
		"sched/sched_swap_numa",
		$regex_sched_swap_numa_default,
		"src_pid", "src_tgid", "src_ngid", "src_cpu", "src_nid", "dst_pid", "dst_tgid", "dst_ngid", "dst_cpu", "dst_nid");
	$regex_sched_migrate_task = $self->generate_traceevent_regex(
		"sched/sched_migrate_task",
		$regex_sched_migrate_task_default,
		"comm", "pid", "prio", "orig_cpu", "dest_cpu");

	$self->{_FieldLength} = 16;

	my $numactl = $self->SUPER::open_log("$reportDir/numactl.txt");
	while (!eof($numactl)) {
		my $line = <$numactl>;
		if ($line =~ /^node ([0-9]*) cpus: (.*)/) {
			my $nid = $1;

			foreach my $cpu (split /\s/, $2) {
				$cpu_nid{$cpu} = $nid;
			}
		}
	}

	my @ftraceCounters;
	$self->{_FtraceCounters} = \@ftraceCounters;
}

sub ftraceCallback {
	my ($self, $timestamp, $pid, $process, $tracepoint, $details) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};

	if ($tracepoint eq "sched_move_task") {
		my $retry = $task_migrated{"$pid-$process"};
		if ($details !~ /$regex_sched_move_task/p) {
			print "WARNING: Failed to parse sched_move_task as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_move_task\n";
			return;
		}

		@$ftraceCounterRef[TASK_MIGRATE_IDLE]++;
		if ($retry) {
			@$ftraceCounterRef[TASK_MIGRATE_RETRY]++;
			@$ftraceCounterRef[TASK_MIGRATE_RETRY_SUCCESS]++;
		}
		if ($5 == $7) {
			@$ftraceCounterRef[TASK_MIGRATE_IDLE_LOCAL]++;
		}

		$task_migrated{"$pid-$process"} = 1
	} elsif ($tracepoint eq "sched_stick_numa") {
		my $retry = $task_migrated{"$pid-$process"};

		if ($details !~ /$regex_sched_stick_numa/p) {
			print "WARNING: Failed to parse sched_stick_numa as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_stick_numa\n";
			return;
		}

		# src_pid	$1
		# src_tgid	$2
		# src_ngid	$3
		# src_cpu	$4
		# src_nid	$5
		# dst_pid	$6
		# dst_tgid	$7
		# dst_ngid	$8
		# dst_cpu	$9
		# dst_nid	$10

		if ($9 == -1) {
			@$ftraceCounterRef[TASK_MIGRATE_STICK_NOCPU]++;
		} elsif ($6 == 0) {
			@$ftraceCounterRef[TASK_MIGRATE_STICK_IDLEFAIL]++;
		} elsif ($6 > 0) {
			@$ftraceCounterRef[TASK_MIGRATE_STICK_SWAPFAIL]++;
		}
		if ($retry) {
			@$ftraceCounterRef[TASK_MIGRATE_RETRY]++;
			@$ftraceCounterRef[TASK_MIGRATE_RETRY_FAIL]++;
		}
		$task_migrated{"$pid-$process"} = 1
	} elsif ($tracepoint eq "sched_move_numa") {
		if ($details !~ /$regex_sched_move_numa/p) {
			print "WARNING: Failed to parse sched_move_numa as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_move_numa\n";
			return;
		}

		@$ftraceCounterRef[TASK_MIGRATE_IDLE]++;
		@$ftraceCounterRef[LOAD_BALANCE_CROSS_NUMA]--;

	} elsif ($tracepoint eq "sched_swap_numa") {
		if ($details !~ /$regex_sched_swap_numa/p) {
			print "WARNING: Failed to parse sched_swap_numa as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_swap_numa\n";
			return;
		}

		@$ftraceCounterRef[TASK_MIGRATE_SWAP]++;
		@$ftraceCounterRef[LOAD_BALANCE_CROSS_NUMA] -= 2;

		my $src_ngid = $3;
		my $dst_ngid = $8;
		my $src_nid = $5;
		my $dst_nid = $10;
		if ($src_nid == $dst_nid) {
			@$ftraceCounterRef[TASK_MIGRATE_SWAP_LOCAL]++;
		}
		if ($src_ngid > 0 && $src_ngid == $dst_ngid) {
			@$ftraceCounterRef[TASK_MIGRATE_SWAP_GROUP]++;
		}
	} elsif ($tracepoint eq "sched_migrate_task") {
		if ($details !~ /$regex_sched_migrate_task/p) {
			print "WARNING: Failed to parse sched_migrate_task as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_migrate_task\n";
			return;
		}

		# Fields (look at the regex)
		# 1: comm (name of task)
		# 2: pid
		# 3: prio
		# 4: orig_cpu
		# 5: dest_cpu
		if ($cpu_nid{$4} != $cpu_nid{$5}) {
			@$ftraceCounterRef[LOAD_BALANCE_CROSS_NUMA]++;
		}

	} else {
		@$ftraceCounterRef[EVENT_UNKNOWN]++;
	}
}

sub ftraceReport {
	my ($self, $rowOrientated) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};

	for (my $key = 0; $key < EVENT_UNKNOWN; $key++) {
		if (!defined($_fieldIndexMap[$key])) {
			next;
		}

		my $keyName = $_fieldIndexMap[$key];
		if ($rowOrientated && $_fieldNameMap{$keyName}) {
			$keyName = $_fieldNameMap{$keyName};
		}

		$self->addData($keyName, 0, $ftraceCounterRef->[$key] );
	}
	%task_migrated = ();
}

1;
