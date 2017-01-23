# MonitorFtraceallocstall.pm
package MMTests::MonitorFtraceallocstall;
use MMTests::MonitorFtracepairlatency;
our @ISA = qw(MMTests::MonitorFtracepairlatency);
use strict;

sub ftraceInit() {
	my $self = shift @_;

	$self->add_regex_start("vmscan/mm_vmscan_direct_reclaim_begin",
		'order=([0-9]*) may_writepage=([0-9]*) gfp_flags=([A-Z_|]+)',
		"order", "may_writepage", "gfp_flags");

	$self->add_regex_end("vmscan/mm_vmscan_direct_reclaim_end",
		"nr_reclaimed=([0-9]*)",
		"nr_reclaimed");

	$self->SUPER::ftraceInit();

	return $self;
}

sub ftraceReport() {
}
