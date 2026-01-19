sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = discover_scaling_parameters($reportDir, "threads-", ".log.gz");

	foreach my $client (@clients) {
		my $base = 0;
		my $huge = 0;

		my $input = open_log("$reportDir/threads-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /^fault/) {
				my @elements = split(/\s+/, $line);
				if ($elements[2] eq "base") {
					$base++;
				} else {
					$huge++;
				}
			}
		}
		close $input;

		my $percentage;
		if ($huge + $base != 0) {
			$percentage = $huge * 100 / ($huge + $base);
		} else {
			$percentage = -1;
		}
		print "huge\t$client\t_\t1\t$percentage\t_\n";
	}
}

1;
