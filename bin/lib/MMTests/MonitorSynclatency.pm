# MonitorSynclatency.pm
package MMTests::MonitorSynclatency;
use MMTests::MonitorLatency;
our @ISA = qw(MMTests::MonitorLatency);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorSynclatency",
		_DataType      => DataTypes::DATA_TIME_SECONDS,
		_Heading       => "sync-latency",
		_PlotYaxis     => "Sync Latency (s)",
	};
	bless $self, $class;
	return $self;
}

1;
