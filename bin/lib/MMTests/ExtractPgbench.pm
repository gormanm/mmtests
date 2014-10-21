# ExtractPgbench.pm
package MMTests::ExtractPgbench;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractPgbench";
	$self->{_DataType}   = MMTests::Extract::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;

	my @files = <$reportDir/noprofile/default/pgbench-raw-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client transaction information
	foreach my $client (@clients) {
		$iteration = 0;

		my @files = <$reportDir/noprofile/default/pgbench-raw-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /^tps/ && $_ =~ /including/) {
					my @elements = split(/\s+/, $_);
					push @{$self->{_ResultData}}, [ $client, $iteration, $elements[2] ];
					$iteration++;
				}
			}
			close INPUT;
		}
	}

	$self->{_Operations} = \@clients;
}

1;
