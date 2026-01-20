sub extractReport($$) {
	my ($self, $reportDir) = @_;

	my @clients = discover_scaling_parameters($reportDir, "sysbench-raw-", "-1");;
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/sysbench-raw-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				next if $line !~ /.*transactions:.*per sec/;
				my @elements = split(/\s+/, $line);
				my $ops = $elements[3];
				$ops =~ s/\(//;
				print "txn/sec\t$client\t_\t$iteration\t$ops\t_\n";
				$iteration++;
			}
			close INPUT;
		}
	}
}

1;
