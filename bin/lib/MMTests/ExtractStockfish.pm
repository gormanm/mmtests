# ExtractStockfish.pm
package MMTests::ExtractStockfish;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractStockfish";
	$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
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
			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				my $line = $_;
				if ($line =~ /^info nodes ([0-9]+) time ([0-9]+)/) {
					$self->addData("totalnps-$thread", ++$iteration, $1/$2);
				}
			}
			close($input);
		}
	}
}

1;
