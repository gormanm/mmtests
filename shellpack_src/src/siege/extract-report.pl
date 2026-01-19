sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = discover_scaling_parameters($reportDir, "siege-", "-1.log");

	foreach my $client (@clients) {
		my @files = <$reportDir/siege-$client-*.log>;
		my $iteration = 0;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				next if $line !~ /Transaction rate:/;
				my @elements = split(/\s+/, $line);
				$iteration++;
				print "txn/sec\t$client\t_\t$iteration\t$elements[-2]\t_\n";
			}
			close INPUT;
		}
	}
}

1;
