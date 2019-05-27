# ExtractParalleldd.pm
package MMTests::ExtractParalleldd;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractParalleldd";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @instances = $self->discover_scaling_parameters($reportDir, "time-", "-1-1");

	# Extract per-instance timing information
	foreach my $instance (@instances) {
		my $iteration = 0;

		foreach my $file (<$reportDir/time-$instance-*>) {
			$self->parse_time_elapsed($file, $instance, ++$iteration);
		}
	}
}

1;
