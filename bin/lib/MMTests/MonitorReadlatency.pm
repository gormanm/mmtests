# MonitorReadlatency.pm
package MMTests::MonitorReadlatency;
use MMTests::MonitorLatency;
our @ISA = qw(MMTests::MonitorLatency);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorReadlatency",
		_Heading       => "read-latency",
		_PlotYaxis     => "Read Latency (ms)",
	};
	bless $self, $class;
	return $self;
}

1;
