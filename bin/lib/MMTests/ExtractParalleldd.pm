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
	my @instances = $self->discover_scaling_parameters($reportDir, "time-", ".log.gz");

	# Extract per-instance timing information
	foreach my $instance (@instances) {
		# Note that there are separate instances and we do not report
		# differences in throughput between parallel instances
		my $iteration = 0;

		my @files = <$reportDir/time-$instance-*.*>;
		my $input = $self->SUPER::open_log("$reportDir/time-$instance.log");
		while (<$input>) {
			next if $_ !~ /elapsed/;
			$self->addData($instance, ++$iteration, $self->_time_to_elapsed($_));
		}
		close($input);
	}
}

1;
