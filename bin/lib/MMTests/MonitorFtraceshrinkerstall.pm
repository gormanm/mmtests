# MonitorFtraceshrinkerstall.pm
package MMTests::MonitorFtraceshrinkerstall;
use MMTests::MonitorFtracepairlatency;
our @ISA = qw(MMTests::MonitorFtracepairlatency);
use strict;

sub ftraceInit() {
	my $self = shift @_;

	$self->add_regex_start_noverify("vmscan/mm_shrink_slab_start",
		'([0-9a-z+_/]+) (?:\[[A-Za-z0-9_-]+\] )?([0-9a-fx]+): nid: ([0-9]*) objects to shrink ([0-9]*) gfp_flags ([A-Z0-9x|_]+) pgs_scanned ([0-9]*) lru_pgs ([0-9]*) cache items ([0-9]*) delta ([0-9]*) total_scan ([0-9]*)');

	$self->add_regex_end_noverify("vmscan/mm_shrink_slab_end",
		'([0-9a-z+_/]+) (?:\[[A-Za-z0-9_-]+\] )?([0-9a-fx]+): unused scan count ([0-9]*) new scan count ([0-9]*) total_scan ([-0-9]*) last shrinker return val ([0-9]*)');

	$self->set_delay_threshold(1);

	$self->SUPER::ftraceInit();

	return $self;
}

sub ftraceReport() {
}
