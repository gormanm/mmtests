# ExtractSysbench.pm
package MMTests::ExtractSysbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSysbench";
	$self->{_DataType}   = DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;

	my @clients;
	my @files = <$reportDir/$profile/default/sysbench-raw-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client transaction information
	foreach my $client (@clients) {
		$iteration = 0;

		my @files = <$reportDir/$profile/default/sysbench-raw-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				next if $line !~ /.*transactions:.*per sec/;
				my @elements = split(/\s+/, $line);
				my $ops = $elements[3];
				$ops =~ s/\(//;
				push @{$self->{_ResultData}}, [ $client, $iteration, $ops ];
				$iteration++;
			}
			close INPUT;
		}
	}

	$self->{_Operations} = \@clients;
}

1;
