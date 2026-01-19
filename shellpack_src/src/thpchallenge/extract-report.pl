sub extractReport() {
	my ($self, $reportDir) = @_;
	my @ops;
	my @clients = discover_scaling_parameters($reportDir, "threads-", ".log.gz");

	foreach my $client (@clients) {
		my $faults = 0;
		my $inits = 0;
		my %seen;

		my $input = open_log("$reportDir/threads-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /^fault/) {
				my @elements = split(/\s+/, $line);
				$faults++;
				print "fault-$elements[2]\t$client\t_\t$faults\t$elements[3]\t_\n";
				print "fault-both\t$client\t_\t$faults\t$elements[3]\t_\n";
				$seen{$elements[2]} = 1;
			}
		}
		close $input;

		if ($seen{"base"} != 1) {
			print "fault-base\t$client\t_\t1\t0\t_\n";
		}
		if ($seen{"huge"} != 1) {
			print "fault-huge\t$client\t_\t1\t0\t_\n";
		}
	}
}

1;
