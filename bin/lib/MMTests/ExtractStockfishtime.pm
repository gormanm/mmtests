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
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;
	$reportDir =~ s/stockfishtime/stockfish/;

	my @files = <$reportDir/stockfish-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract timing information
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/time-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("elapsed-$client", ++$iteration, $self->_time_to_elapsed($_));
			}
			close(INPUT);
		}
	}
}

1;
