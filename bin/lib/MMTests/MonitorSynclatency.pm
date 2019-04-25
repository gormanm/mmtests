# MonitorSynclatency.pm
package MMTests::MonitorSynclatency;
use MMTests::MonitorLatency;
our @ISA = qw(MMTests::MonitorLatency);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorSynclatency",
		_DataType      => MMTests::Monitor::MONITOR_LATENCY,
		_Heading       => "sync-latency",
		_NiceHeading   => "Sync Latency",
		_Units         => "s"
	};
	bless $self, $class;
	return $self;
}

1;
