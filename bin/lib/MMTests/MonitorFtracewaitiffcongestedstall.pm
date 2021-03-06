# MonitorFtracewaitiffcongestedstall.pm
package MMTests::MonitorFtracewaitiffcongestedstall;
use MMTests::MonitorFtracesinglelatency;
our @ISA = qw(MMTests::MonitorFtracesinglelatency);
use strict;

sub ftraceInit() {
	my $self = shift @_;

	$self->add_regex("writeback/writeback_wait_iff_congested",
		"usec_timeout=([0-9]*) usec_delayed=([0-9]*)",
		2);
		"usec_timeout", "usec_delayed",

	$self->set_delay_threshold(0);
	$self->SUPER::ftraceInit();

	return $self;
}

sub ftraceReport() {
}
