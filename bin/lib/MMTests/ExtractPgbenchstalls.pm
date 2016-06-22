# ExtractPgbenchstalls.pm
package MMTests::ExtractPgbenchstalls;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractPgbenchstalls";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;
	# $self->{_Variable}   = 1;
	$self->{_DefaultPlot} = "1";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my @clients;

	$reportDir =~ s/pgbenchstalls/pgbench/;

	my @files = <$reportDir/noprofile/default/pgbench-raw-*>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
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

		my $file = "$reportDir/noprofile/default/pgbench-transactions-$client-1";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my @elements = split(/\s+/, $_);
			push @values, $elements[1];
			my $nrTransactions = $elements[1];
		}
		close(INPUT);
		$stallThreshold = int (calc_mean(@values) / 4);
		$#values = -1;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			# time num_of_transactions latency_sum latency_2_sum min_latency max_latency
			my @elements = split(/\s+/, $_);
			my $nrTransactions = $elements[1];
			$sample++;
			if ($nrTransactions < $stallThreshold) {
				if ($stallStart == 0) {
					$stallStart = $elements[0];
				}
			} else {
				if ($stallStart) {
					my $stallDuration = $elements[0] - $stallStart;
					$stallStart = 0;
					push @values, $stallDuration;
				}
			}
		}
		close INPUT;

		push @{$self->{_ResultData}}, [ "NrStalls-$client", $#values + 1];
		if ($#values >= 0) {
			push @{$self->{_ResultData}}, [ "MinStall-$client", calc_min(@values) ];
			push @{$self->{_ResultData}}, [ "AvgStall-$client", calc_mean(@values) ];
			push @{$self->{_ResultData}}, [ "MaxStall-$client", calc_max(@values) ];
			push @{$self->{_ResultData}}, [ "TotStall-$client", calc_sum(@values) ];
		} else {
			push @{$self->{_ResultData}}, [ "MinStall-$client", 0 ];
			push @{$self->{_ResultData}}, [ "AvgStall-$client", 0 ];
			push @{$self->{_ResultData}}, [ "MaxStall-$client", 0 ];
			push @{$self->{_ResultData}}, [ "TotStall-$client", 0 ];
		}
	}
}

1;
