# MonitorReadlatency.pm
package MMTests::MonitorReadlatency;
use MMTests::MonitorLatency;
our @ISA = qw(MMTests::MonitorLatency); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorReadlatency",
		_DataType      => MMTests::Monitor::MONITOR_LATENCY,
		_ResultData    => [],
		_Heading       => "read-latency",
		_NiceHeading   => "Read Latency",
		_Units         => "ms"
	};
	bless $self, $class;
	return $self;
}

1;
