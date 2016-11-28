# ExtractDbt5latency.pm
package MMTests::ExtractDbt5latency;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractDbt5latency";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;
	$self->{_ExactSubheading} = 1;
	$self->{_ExactPlottype} = "simple";
	$self->{_DefaultPlot} = "1";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my @clients;
	$reportDir =~ s/dbt5latency/dbt5-bench/;

	my @files = <$reportDir/$profile/results-*-1.txt>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client transaction information
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/$profile/results-$client-*.txt>;
		foreach my $file (@files) {
			my $reading = 0;
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /^----/) {
					$reading = !$reading;
					next;
				}
				next if !$reading;
				my @elements = split(/\s+/);
				push @{$self->{_ResultData}}, [ $client, ++$iteration, $elements[4] ];
			}
			close(INPUT);
		}
	}

	$self->{_Operations} = \@clients;
}

1;
