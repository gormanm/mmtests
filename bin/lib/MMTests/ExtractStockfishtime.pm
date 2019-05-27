# ExtractStockfishtime.pm
package MMTests::ExtractStockfishtime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractStockfishtime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @threads = $self->discover_scaling_parameters($reportDir, "stockfish-", "-1.gz");

	# Extract timing information
	foreach my $thread (@threads) {
		my $iteration = 0;

		my @files = <$reportDir/time-$thread-*>;
		foreach my $file (<$reportDir/time-$thread-*>) {
			$self->parse_time_elapsed($file, $thread, ++$iteration);
		}
	}
}

1;
