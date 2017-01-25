# MonitorFtracecompactstall.pm
package MMTests::MonitorFtracecompactstall;
use MMTests::MonitorFtracepairlatency;
our @ISA = qw(MMTests::MonitorFtracepairlatency);
use strict;

sub ftraceInit() {
	my $self = shift @_;

	$self->add_regex_start("compaction/mm_compaction_begin",
		"zone_start=([0-9a-fx]*) migrate_pfn=([0-9a-fx]*) free_pfn=([0-9a-fx]*) zone_end=([0-9a-fx]*)",
		"zone_start", "migrate_pfn", "free_pfn", "zone_end");

	$self->add_regex_end("vmscan/mm_compaction_end",
		"nr_reclaimed=([0-9]*)",
		"status=([0-9]*)");

	$self->SUPER::ftraceInit();

	return $self;
}

sub ftraceReport() {
}
