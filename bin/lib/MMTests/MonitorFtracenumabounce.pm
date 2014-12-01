# MonitorFtracenumabounce.pm
package MMTests::MonitorFtracenumabounce;
use MMTests::MonitorFtrace;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

# Tracepoint events
use constant NUMA_MIGRATE_PAGE			=> 1;
use constant EVENT_UNKNOWN			=> 10;

# Defaults for dynamically discovered regex's
my $regex_mm_numab_migrate_page_default = 'comm=([a-zA-Z0-9-.]*) pid=([0-9]*) mmid=(0x[0-9a-fA-F]*) address=(0x[0-9a-fA-F]*) src_nid=([0-9]*) dst_nid=([0-9]) nr_pages=([0-9]*) flags=([a-zA-Z]*)';

# Dynamically discovered regex
my $regex_mm_numab_migrate_page;

sub ftraceInit {
	my $self = $_[0];
	$regex_mm_numab_migrate_page = $self->generate_traceevent_regex(
		"migrate/mm_numab_migrate_page",
		$regex_mm_numab_migrate_page_default,
		"comm", "pid", "mmid", "address", "src_nid", "dst_nid", "nr_pages", "flags");

	$self->{_FieldLength} = 32;

	my @ftraceCounters;
	my %pageCounters;
	$self->{_FtraceCounters} = \@ftraceCounters;
	$self->{_FtraceCounters}[NUMA_MIGRATE_PAGE] = \%pageCounters;
}

sub ftraceCallback {
	my ($self, $timestamp, $pid, $process, $tracepoint, $details) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};

	if ($tracepoint eq "mm_numab_migrate_page") {
		if ($details !~ /$regex_mm_numab_migrate_page/p) {
			print "WARNING: Failed to parse mm_numa_migrate_ratelimit as expected\n";
			print "	 $details\n";
			print "	 $regex_mm_numab_migrate_page\n";
			return;
		}

		@$ftraceCounterRef[NUMA_MIGRATE_PAGE]->{"$1-$2-mmid$3-addr$4-$8-$7"}++;
	} else {
		@$ftraceCounterRef[EVENT_UNKNOWN]++;
	}
}

sub ftraceReport {
	my ($self, $rowOrientated) = @_;
	my $i;
	my (@headers, @fields, @format);
	my $ftraceCounterRef = $self->{_FtraceCounters};
	my %pageCounter = %{@$ftraceCounterRef[NUMA_MIGRATE_PAGE]};

	foreach my $key (sort { $pageCounter{$b} <=> $pageCounter{$a} } keys %pageCounter) {
		if ($pageCounter{$key} > 1) {
			printf("%-64s %8d\n", $key, $pageCounter{$key})
		}
	}
}

1;
