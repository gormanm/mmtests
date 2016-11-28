# ExtractDvdstore.pm
package MMTests::ExtractDvdstore;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractDvdstore";
	$self->{_DataType}   = MMTests::Extract::DATA_TRANS_PER_MINUTE;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;
	$self->{_ExactSubheading} = 1;
	$self->{_ExactPlottype} = "simple";
	# $self->{_Variable}   = 1;
	$self->{_DefaultPlot} = "1";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my @clients;

	my @files = <$reportDir/$profile/dvdstore-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;
	my $stallStart = 0;

	# Extract per-client transaction information
	foreach my $client (@clients) {
		my $sample = 0;
		my $stallStart = 0;
		my $stallThreshold = 0;
		my @values;
		my $startSamples = 0;
		my $endSamples = 0;

		my $reading = 0;
		my $file = "$reportDir/$profile/dvdstore-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			if ($line =~ /Stats reset/) {
				$reading = 1;
				next;
			}

			if ($line =~ /^et=\s*([0-9]+).*opm=([0-9]+).*/) {
				push @{$self->{_ResultData}}, [ $client, $1, $2 ];
			}
		}
		close INPUT;
	}

	$self->{_Operations} = \@clients;
}

1;
