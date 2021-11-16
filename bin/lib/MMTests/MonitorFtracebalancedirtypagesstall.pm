# MonitorFtracebalancedirtypagesstall.pm
package MMTests::MonitorFtracebalancedirtypagesstall;
use MMTests::MonitorFtracesinglelatency;
our @ISA = qw(MMTests::MonitorFtracesinglelatency);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_SummaryStats} = [ "min", "percentile-25", "percentile-50",
		"percentile-75", "percentile-1", "percentile-5",
		"percentile-10", "percentile-90",  "percentile-95",
		"percentile-99", "max", "_mean", "samples", "samples-0,5",
		"samples-5,10", "samples-10,20", "samples-20,30",
		"samples-30,35", "samples-35,40", "samples-40,50",
		"samples-50,60", "samples-60,100", "samples-100,500",
		"samples-500,1000", "samples-1000,5000", "samples-5000,max" ];
	$self->SUPER::initialise($subHeading);
}

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

	$self->SUPER::ftraceInit();

	return $self;
}

sub ftraceReport() {
}
