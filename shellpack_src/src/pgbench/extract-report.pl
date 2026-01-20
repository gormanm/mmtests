sub extractReport($$) {
	my ($self, $reportDir) = @_;
	my @clients;
	my $input;

	@clients = discover_scaling_parameters($reportDir, "pgbench-", ".log");

	# Extract per-client transaction information
	foreach my $client (@clients) {
		my $sample = 0;

		my $testStart = 0;
		my $batchStart = 0;
		my $sumTransactions = 0;
		my $this_batch = 0;
		my $nr_batches = 0;
		my $batch_size = 4;
		my $startSamples = ($batch_size * 2);

		# Format
		# interval_start
		# num_transactions
		# sum_latency_2
		# min_latency
		# max_latency
		$input = open_log("$reportDir/pgbench-transactions-$client.log");
		while (<$input>) {
			my @elements = split(/\s+/, $_);
			my $nrTransactions = $elements[1];
			$testStart = $elements[0]  if ($testStart == 0);
			$batchStart = $elements[0] if ($batchStart == 0);
			$sample++;
			next if ($sample < $startSamples);

			$this_batch++;
			$sumTransactions += $nrTransactions;
			if ($this_batch % $batch_size == 0) {
				my $elapsed = $elements[0] - $testStart;
				my $trans_sec = ($sumTransactions / ($elements[0] - $batchStart));
				print "txn\t$client\t_\t$elapsed\t$trans_sec\t_\n" if $nr_batches > 0;
				$nr_batches++;
				$batchStart = $elements[0];
				$this_batch = 0;
				$sumTransactions = 0;
			}
		}
		close($input);
	}
}

1;
