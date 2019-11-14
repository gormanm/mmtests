# ExtractPgbench.pm
package MMTests::ExtractPgbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName}		= "ExtractPgbench";
	$self->{_DataType}		= DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}		= "client-errorlines";
	$self->{_SubheadingPlotType}	= "simple-clients";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients;
	my $input;

	@clients = $self->discover_scaling_parameters($reportDir, "pgbench-", ".log");

	# Extract per-client transaction information
	foreach my $client (@clients) {
		my $sample = 0;
		my @values;
		my $startSamples = 1;
		my $endSamples = 0;

		$input = $self->SUPER::open_log("$reportDir/pgbench-transactions-$client.log");
		while (<$input>) {
			my @elements = split(/\s+/, $_);
			push @values, $elements[1];
			$endSamples++;
		}
		close($input);

		my $testStart = 0;
		my $sumTransactions = 0;
		my $nr_readings = 0;
		my $thisBatch = 0;
		# my $batch = int (($endSamples - $startSamples) / 12);
		my $batch = 4;
		if ($batch <= 0) {
			$batch = 1;
		}
		$startSamples += ($batch * 2);
		$input = $self->SUPER::open_log("$reportDir/pgbench-transactions-$client.log");
		while (<$input>) {
			# time num_of_transactions latency_sum latency_2_sum min_latency max_latency
			my @elements = split(/\s+/, $_);
			my $nrTransactions = $elements[1];
			if ($testStart == 0) {
				$testStart = $elements[0];
			}
			$sample++;
			if ($sample > $startSamples && $sample <= $endSamples) {
				$thisBatch++;
				$sumTransactions += $nrTransactions;
				if ($thisBatch % $batch == 0) {
					my $trans = $sumTransactions / $batch;
					if ($trans == 0) {
						$trans = 1;
					}
					$self->addData($client, $elements[0] - $testStart, $trans );
					$thisBatch = 0;
					$sumTransactions = 0;
					$nr_readings++;
				}
			}
		}
		close($input);
		if ($nr_readings == 0) {
			$input = $self->SUPER::open_log("$reportDir/pgbench-$client.log");
			while (!eof($input)) {
				my $line = <$input>;
				if ($line =~ /^tps = ([0-9.]+) \(including.*/) {
					$self->addData($client, 0, $1);
				}
			}
			close($input);
		}
	}
}

1;
