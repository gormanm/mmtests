# MonitorFtracebalancedirtypagesstall.pm
package MMTests::MonitorFtracebalancedirtypagesstall;
use MMTests::MonitorFtracesinglelatency;
our @ISA = qw(MMTests::MonitorFtracesinglelatency);
use strict;

sub ftraceInit() {
	my $self = shift @_;

	$self->add_regex("writeback/balance_dirty_pages",
		"bdi ([a-zA-Z0-9:/]*) limit=([0-9]*) setpoint=([0-9]*) dirty=([0-9]*) bdi_setpoint=([0-9]*) bdi_dirty=([0-9]*) dirty_ratelimit=([0-9]*) task_ratelimit=([0-9]*) dirtied=([0-9]*) dirtied_pause=([0-9]*) paused=([0-9]*) pause=([0-9-]*) period=([0-9]*) think=([0-9-]*) cgroup_ino=([0-9]*)",
		13);
		"usec_timeout", "usec_delayed",

	# Assume HZ=250
	$self->set_jiffie_multiplier(4);

	# Ignore negative pauses that do not call io_schedule_timeout
	$self->set_delay_threshold(0);

	$self->set_thresholds(( 0, 5, 10, 20, 30, 35, 40, 50, 60, 100, 500, 1000, 5000 ));

	$self->SUPER::ftraceInit();

	return $self;
}

sub ftraceReport() {
}
