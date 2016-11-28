# ExtractStockfish.pm
package MMTests::ExtractStockfish;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractStockfish";
	$self->{_DataType}   = MMTests::Extract::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;

	my @files = <$reportDir/$profile/stockfish-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract timing information
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/$profile/stockfish-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
#				if ($line =~ /^info.*nps ([0-9]+) time/) {
#					push @{$self->{_ResultData}}, [ "nps-$client", ++$iteration, $1 ];
#				}
				if ($line =~ /^info nodes ([0-9]+) time ([0-9]+)/) {
					push @{$self->{_ResultData}}, [ "totalnps-$client", ++$iteration, $1/$2 ];
				}
			}
			close(INPUT);
		}
	}

	my @ops;
	for my $heading ("totalnps") {
		foreach my $client (@clients) {
			push @ops, "$heading-$client";
		}
	}

	$self->{_Operations} = \@ops;
}

1;
