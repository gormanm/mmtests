# MonitorFtraceschedmigrate.pm
package MMTests::MonitorFtraceschedmigrate;
use MMTests::MonitorFtrace;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

# Tracepoint events
use constant SCHED_MIGRATE_TASK			=> 1;
use constant SCHED_MIGRATE_TASK_LOCAL		=> 2;
use constant SCHED_MIGRATE_TASK_REMOTE		=> 3;
use constant EVENT_UNKNOWN			=> 5;

# Defaults for dynamically discovered regex's
my $regex_sched_migrate_task_default = 'comm=([a-zA-Z0-9-._\[\]\/\(\): ]*) pid=([0-9]*) prio=([0-9]*) orig_cpu=([0-9]*) dest_cpu=([0-9]*)';

# Dynamically discovered regex
my $regex_sched_migrate_task;

my @_fieldIndexMap;
$_fieldIndexMap[SCHED_MIGRATE_TASK]			= "sched_migrate_task";
$_fieldIndexMap[SCHED_MIGRATE_TASK_LOCAL]		= "sched_migrate_task_local";
$_fieldIndexMap[SCHED_MIGRATE_TASK_REMOTE]		= "sched_migrate_task_remote";
$_fieldIndexMap[EVENT_UNKNOWN]				= "event_unknown";

my %_fieldNameMap = (
	"sched_migrate_task"			=> "Task cpu migration",
	"sched_migrate_task_remote"		=> "Task cpu migration local",
	"sched_migrate_task_remote"		=> "Task cpu migration remote",
	"event_unknown"				=> "Unrecognised events",
);

my %cpu_nid;

sub ftraceInit {
	my ($self, $reportDir, $testBenchmark, $subHeading) = @_;
	$regex_sched_migrate_task = $self->generate_traceevent_regex(
		"sched/sched_migrate_task",
		$regex_sched_migrate_task_default,
		"comm", "pid", "prio", "orig_cpu", "dest_cpu");

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

	if ($tracepoint eq "sched_migrate_task") {
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

		@$ftraceCounterRef[SCHED_MIGRATE_TASK]++;
		if ($cpu_nid{$4} == $cpu_nid{$5}) {
			@$ftraceCounterRef[SCHED_MIGRATE_TASK_LOCAL]++;
		} else {
			@$ftraceCounterRef[SCHED_MIGRATE_TASK_REMOTE]++;
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

		$self->addData($keyName, 0, $ftraceCounterRef->[$key] );
	}
}

1;
