# MonitorFtracenumatraffictotal.pm
package MMTests::MonitorFtracenumatraffictotal;
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

	$self->{_FieldLength} = 12;

	my @ftraceCounters;
	my %migrateFrom;
	my %migrateTo;
	$self->{_FtraceCounters} = \@ftraceCounters;
	$self->{_FtraceCounters}[NUMA_MIGRATE_MISPLACED_PAGE_FROM] = \%migrateFrom;
	$self->{_FtraceCounters}[NUMA_MIGRATE_MISPLACED_PAGE_TO] = \%migrateTo;
}

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

		$max_nid = $4 if $4 > $max_nid;
		$max_nid = $5 if $5 > $max_nid;
	} else {
		@$ftraceCounterRef[EVENT_UNKNOWN]++;
	}
}

sub ftraceReport {
	my ($self, $rowOrientated) = @_;
	my $i;
	my (@headers, @fields, @format);
	my $ftraceCounterRef = $self->{_FtraceCounters};
	my %migrateFrom = %{@$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_FROM]};
	my %migrateTo = %{@$ftraceCounterRef[NUMA_MIGRATE_MISPLACED_PAGE_TO]};

	for ($i = 0; $i <= $max_nid; $i++) {
		printf("Migrate from node %d %8d\n", $i, $migrateFrom{$i});
		printf("Migrate to   node %d %8d\n", $i, $migrateTo{$i});
	}
}

1;
