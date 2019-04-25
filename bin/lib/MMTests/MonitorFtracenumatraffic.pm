# MonitorFtracenumatraffic.pm
package MMTests::MonitorFtracenumatraffic;
use MMTests::MonitorFtrace;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

# Tracepoint events
use constant NUMA_MIGRATE_MISPLACED_PAGE_FROM	=> 1;
use constant NUMA_MIGRATE_MISPLACED_PAGE_TO	=> 2;
use constant EVENT_UNKNOWN			=> 3;

# Defaults for dynamically discovered regex's
my $regex_mm_migrate_misplaced_pages_default = 'comm=([a-zA-Z0-9-._ ]*) pid=([0-9]*) tgid=([0-9]*) src_nid=([0-9]*) dst_nid=([0-9]) nr_pages=([0-9]*)';

# Dynamically discovered regex
my $regex_mm_migrate_misplaced_pages;

my $max_nid = 0;

sub ftraceInit {
	my $self = $_[0];
	$regex_mm_migrate_misplaced_pages = $self->generate_traceevent_regex(
		"migrate/mm_migrate_misplaced_pages",
		$regex_mm_migrate_misplaced_pages_default,
		"comm", "pid", "tgid", "src_nid", "dst_nid", "nr_pages");

	my @ftraceCounters;
	my %migrateFrom;
	my %migrateTo;
	$self->{_FtraceCounters} = \@ftraceCounters;
	$self->{_FtraceCounters}[NUMA_MIGRATE_MISPLACED_PAGE_FROM] = \%migrateFrom;
	$self->{_FtraceCounters}[NUMA_MIGRATE_MISPLACED_PAGE_TO] = \%migrateTo;
}

my $last_timestamp = 0;
my $start_timestamp = 0;
my $window = 30;

sub ftraceCallback {
	my ($self, $timestamp, $pid, $process, $tracepoint, $details) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};

	if ($tracepoint eq "mm_migrate_misplaced_pages") {
		if ($details !~ /$regex_mm_migrate_misplaced_pages/p) {
			print "WARNING: Failed to parse mm_migrate_misplaced_page as expected\n";
			print "	 $details\n";
			print "	 $regex_mm_migrate_misplaced_pages\n";
			return;
		}

		@$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_FROM]->{"$4"} += $6;
		@$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_TO]->{"$5"}   += $6;

		$timestamp /= 1000;
		$timestamp = int $timestamp;
		$start_timestamp = int $timestamp if $start_timestamp == 0;
		$timestamp -= $start_timestamp;
		$last_timestamp = int $timestamp if $last_timestamp == 0;

		$max_nid = $4 if $4 > $max_nid;
		$max_nid = $5 if $5 > $max_nid;

		if ($timestamp - $last_timestamp > $window) {
			my $nid;
			my $this_stamp;

			for ($nid = 0; $nid <= $max_nid; $nid++) {
				# for ($this_stamp = $last_timestamp + 1; $this_stamp < $timestamp; $this_stamp++) {
				#	printf("%-8d from-$nid %8d\n", $this_stamp, 0);
				#	printf("%-8d   to-$nid %8d\n", $this_stamp, 0);
				#}

				if (@$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_FROM]->{$nid} > 0) {
					printf("%-8d from-$nid %8d\n", $timestamp, @$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_FROM]->{$nid});
				}
				if (@$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_TO]->{$nid} > 0) {
					printf("%-8d   to-$nid %8d\n", $timestamp, @$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_TO]->{$nid});
				}
				@$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_FROM]->{$nid} = 0;
				@$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_TO]->{$nid} = 0;
			}
			$last_timestamp = $timestamp;
		}
	} else {
		@$ftraceCounterRef[EVENT_UNKNOWN]++;
	}
}

sub ftraceReport {
}

1;
