# ExtractStockfishtime.pm
package MMTests::ExtractStockfishtime;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractStockfishtime";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;
	$reportDir =~ s/stockfishtime/stockfish/;

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

		my @files = <$reportDir/$profile/time-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				push @{$self->{_ResultData}}, [ "elapsed-$client", ++$iteration, $self->_time_to_elapsed($_) ];
			}
			close(INPUT);
		}
	}

	my @ops;
	for my $heading ("elapsed") {
		foreach my $client (@clients) {
			push @ops, "$heading-$client";
		}
	}

	$self->{_Operations} = \@ops;
}

1;
