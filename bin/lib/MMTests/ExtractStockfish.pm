# ExtractStockfish.pm
package MMTests::ExtractStockfish;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractStockfish";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @threads = $self->discover_scaling_parameters($reportDir, "stockfish-", "-1.gz");

	# Extract timing information
	foreach my $thread (@threads) {
		my $iteration = 0;

		foreach my $file (<$reportDir/stockfish-$thread-*>) {
			open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /^info nodes ([0-9]+) time ([0-9]+)/) {
					$self->addData("totalnps-$thread", ++$iteration, $1/$2);
				}
			}
			close(INPUT);
		}
	}
}

1;
