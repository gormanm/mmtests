# ExtractSysbenchexectime.pm
package MMTests::ExtractSysbenchexectime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSysbenchexectime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	$reportDir =~ s/sysbenchexectime/sysbench/;
	my @threads = $self->discover_scaling_parameters($reportDir, "sysbench-raw-", "-1");
	my $iteration;

	# Extract per-client timing information
	foreach my $thread (@threads) {
		my $iteration = 0;

		foreach my $file (<$reportDir/time-$thread-*>) {
			$self->parse_time_elapsed($file, $thread, ++$iteration);
		}
	}
}

1;
