# MonitorFtracenumabalance.pm
package MMTests::MonitorFtracenumabalance;
use MMTests::MonitorFtrace;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

# Tracepoint events
use constant NUMA_MIGRATE_RATELIMITS		=> 1;
use constant NUMA_MIGRATE_PAGES_RATELIMITED	=> 2;
use constant TASK_MIGRATE_STUCK			=> 3;
use constant TASK_MIGRATE_SWAP			=> 4;
use constant TASK_MIGRATE_IDLE			=> 5;
use constant NUMA_MOVE_LOCAL			=> 6;
use constant NUMA_MOVE_REMOTE			=> 7;
use constant NUMA_SWAP_GROUP			=> 8;
use constant SCHED_MOVE_LOCAL			=> 9;
use constant SCHED_MOVE_REMOTE			=> 10;
use constant EVENT_UNKNOWN			=> 11;

# Defaults for dynamically discovered regex's
my $regex_mm_numa_migrate_ratelimit_default = 'comm=([a-zA-Z0-9-._]*) pid=([0-9]*) dst_nid=([0-9]) nr_pages=([0-9]*)';
my $regex_sched_stick_numa_default = 'pid=([0-9]*) tgid=([0-9]*) ngid=([0-9]*) src_cpu=([0-9]*) src_nid=([0-9]*) dst_cpu=([0-9]*) dst_nid=([0-9])';
my $regex_sched_move_numa_default = 'pid=([0-9]*) tgid=([0-9]*) ngid=([0-9]*) src_cpu=([0-9]*) src_nid=([0-9]*) dst_cpu=([0-9]*) dst_nid=([0-9])';
my $regex_sched_swap_numa_default = 'src_pid=([0-9]*) src_tgid=([0-9]*) src_ngid=([0-9]*) src_cpu=([0-9]*) src_nid=([0-9]*) dst_pid=([0-9]*) dst_tgid=([0-9]*) dst_ngid=([0-9]*) dst_cpu=([0-9]*) dst_nid=([0-9]*)';
my $regex_sched_move_task_default = 'pid=([0-9]*) tgid=([0-9]*) ngid=([0-9]*) src_cpu=([0-9]*) src_nid=([0-9]*) dst_cpu=([0-9]*) dst_nid=([0-9])';

# Dynamically discovered regex
my $regex_mm_numa_migrate_ratelimit;
my $regex_sched_stick_numa;
my $regex_sched_move_numa;
my $regex_sched_swap_numa;
my $regex_sched_move_task;

my @_fieldIndexMap;
$_fieldIndexMap[NUMA_MIGRATE_RATELIMITS]	= "numa_migrate_ratelimits";
$_fieldIndexMap[NUMA_MIGRATE_PAGES_RATELIMITED] = "numa_migrate_pages_ratelimited";
$_fieldIndexMap[TASK_MIGRATE_STUCK]		= "task_migrate_stuck";
$_fieldIndexMap[TASK_MIGRATE_IDLE]		= "task_migrate_idle";
$_fieldIndexMap[TASK_MIGRATE_SWAP]		= "task_migrate_swap";
$_fieldIndexMap[SCHED_MOVE_LOCAL]		= "sched_move_local";
$_fieldIndexMap[NUMA_MOVE_LOCAL]		= "numa_move_local";
$_fieldIndexMap[NUMA_MOVE_REMOTE]		= "numa_move_remote";
$_fieldIndexMap[NUMA_SWAP_GROUP]		= "numa_swap_group";
$_fieldIndexMap[SCHED_MOVE_REMOTE]		= "sched_move_remote";
$_fieldIndexMap[EVENT_UNKNOWN]			= "event_unknown";

my %_fieldNameMap = (
	"numa_migrate_ratelimits"		=> "NUMA Migrate Ratelimited",
	"numa_migrate_pages_ratelimited"	=> "NUMA Migrate Pages Ratelimited",
	"task_migrate_stuck"			=> "Task Migrated Stuck",
	"task_migrate_idle"			=> "Task Migrated Idle CPU",
	"task_migrate_swap"			=> "Task Migrate swapped",
	"numa_move_local"			=> "NUMA move task local node",
	"numa_move_remote"			=> "NUMA move task remote node",
	"numa_swap_group"			=> "NUMA swap tasks within group",
	"sched_move_local"			=> "Sched move local",
	"sched_move_remote"			=> "Sched move remote",
	"event_unknown"				=> "Unrecognised events",
);

sub ftraceInit {
	my $self = $_[0];
	$regex_mm_numa_migrate_ratelimit = $self->generate_traceevent_regex(
		"migrate/mm_numa_migrate_ratelimit",
		$regex_mm_numa_migrate_ratelimit_default,
		"comm", "pid", "dst_nid", "nr_pages");
	$regex_sched_move_task = $self->generate_traceevent_regex(
		"sched/sched_move_task",
		$regex_sched_move_task_default,
		"pid", "tgid", "ngid", "src_cpu", "src_nid", "dst_cpu", "dst_nid");
	$regex_sched_stick_numa = $self->generate_traceevent_regex(
		"sched/sched_stick_numa",
		$regex_sched_stick_numa_default,
		"pid", "tgid", "ngid", "src_cpu", "src_nid", "dst_cpu", "dst_nid");
	$regex_sched_move_numa = $self->generate_traceevent_regex(
		"sched/sched_move_numa",
		$regex_sched_move_numa_default,
		"pid", "tgid", "ngid", "src_cpu", "src_nid", "dst_cpu", "dst_nid");
	$regex_sched_swap_numa = $self->generate_traceevent_regex(
		"sched/sched_swap_numa",
		$regex_sched_swap_numa_default,
		"src_pid", "src_tgid", "src_ngid", "src_cpu", "src_nid", "dst_pid", "dst_tgid", "dst_ngid", "dst_cpu", "dst_nid");

	$self->{_FieldLength} = 16;

	my @ftraceCounters;
	$self->{_FtraceCounters} = \@ftraceCounters;
}

sub ftraceCallback {
	my ($self, $timestamp, $pid, $process, $tracepoint, $details) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};

	if ($tracepoint eq "mm_numa_migrate_ratelimit") {
		if ($details !~ /$regex_mm_numa_migrate_ratelimit/p) {
			print "WARNING: Failed to parse mm_numa_migrate_ratelimit as expected\n";
			print "	 $details\n";
			print "	 $regex_mm_numa_migrate_ratelimit\n";
			return;
		}

		@$ftraceCounterRef[NUMA_MIGRATE_RATELIMITS]++;
		@$ftraceCounterRef[NUMA_MIGRATE_PAGES_RATELIMITED] += $4;
	} elsif ($tracepoint eq "sched_move_task") {
		if ($details !~ /$regex_sched_move_task/p) {
			print "WARNING: Failed to parse sched_move_task as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_move_task\n";
			return;
		}

		if ($5 == $7) {
			@$ftraceCounterRef[SCHED_MOVE_LOCAL]++;
		} else {
			@$ftraceCounterRef[SCHED_MOVE_REMOTE]++;
		}

	} elsif ($tracepoint eq "sched_stick_numa") {
		if ($details !~ /$regex_sched_stick_numa/p) {
			print "WARNING: Failed to parse sched_stick_numa as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_stick_numa\n";
			return;
		}

		@$ftraceCounterRef[TASK_MIGRATE_STUCK]++;

	} elsif ($tracepoint eq "sched_move_numa") {
		if ($details !~ /$regex_sched_move_numa/p) {
			print "WARNING: Failed to parse sched_move_numa as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_move_numa\n";
			return;
		}

		@$ftraceCounterRef[TASK_MIGRATE_IDLE]++;

	} elsif ($tracepoint eq "sched_swap_numa") {
		if ($details !~ /$regex_sched_swap_numa/p) {
			print "WARNING: Failed to parse sched_swap_numa as expected\n";
			print "	 $details\n";
			print "	 $regex_sched_swap_numa\n";
			return;
		}

		@$ftraceCounterRef[TASK_MIGRATE_SWAP]++;

		my $src_ngid = $3;
		my $dst_ngid = $8;
		my $src_nid = $5;
		my $dst_nid = $10;
		if ($src_nid == $dst_nid) {
			@$ftraceCounterRef[NUMA_MOVE_LOCAL]++;
		} else {
			@$ftraceCounterRef[NUMA_MOVE_REMOTE]++;
		}
		if ($src_ngid > 0 && $src_ngid == $dst_ngid) {
			@$ftraceCounterRef[NUMA_SWAP_GROUP]++;
		}
	} else {
		@$ftraceCounterRef[EVENT_UNKNOWN]++;
	}
}

sub ftraceReport {
	my ($self, $rowOrientated) = @_;
	my $i;
	my (@headers, @fields, @format);
	my $ftraceCounterRef = $self->{_FtraceCounters};

	push @headers, "Unit";
	push @fields, 0;
	push @format, "";

	for (my $key = 0; $key < EVENT_UNKNOWN; $key++) {
		if (!defined($_fieldIndexMap[$key])) {
			next;
		}

		my $keyName = $_fieldIndexMap[$key];
		if ($rowOrientated && $_fieldNameMap{$keyName}) {
			$keyName = $_fieldNameMap{$keyName};
		}

		push @{$self->{_ResultData}}, [ $keyName, 0, $ftraceCounterRef->[$key] ];
	}

	$self->{_FieldHeaders} = [ "Op", "Value" ];
	$self->{_FieldFormat} = [ "%-$self->{_FieldLength}s", "", "%12d" ];
}

1;
