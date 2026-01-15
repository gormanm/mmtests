sub extractReport($$) {
	my ($self, $reportDir) = @_;
	my @clients = discover_scaling_parameters($reportDir, "stressng-", "-1.log");

	foreach my $client (@clients) {
		foreach my $file (<$reportDir/stressng-$client-*>) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $iteration = $split[-1];

			open(INPUT, $file) || die("Failed to open $file\n");
			my $reading = 0;
			while (!eof(INPUT)) {
				my $line = <INPUT>;

				if ($line =~ /\(secs\)/) {
					$reading = 1;
					next;
				}
				next if !$reading;

				$line =~ s/.*\] //;
				my @elements = split /\s+/, $line;

				my $testname = $elements[0];
				my $ops_sec = $elements[5];
				print "bops-$testname\t$client\t_\t$iteration\t$ops_sec\t_\n";
			}
			close(INPUT);
		}
	}
}

1;
