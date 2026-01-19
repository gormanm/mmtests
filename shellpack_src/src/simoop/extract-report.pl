sub extractReport() {
	my ($self, $reportDir) = @_;

	my $reading = 0;
	my $lastReport;
	my ($timestamp);
	open(INPUT, "$reportDir/simoop.log") || die "Failed to open simoop.log";
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		chomp($line);

		if ($line =~ /^Warmup complete/) {
			$reading = 1;
		}
		if ($line =~ /^Final stats/) {
			$reading = 0;
		}
		next if !$reading;

		if ($line =~ /Run time: ([0-9]*) seconds/) {
			$timestamp = $1;
			next;
		}

		my ($op, $p50,  $p95,  $p99, $max);
		if ($line =~ /([a-zA-Z]*) latency usec: \(p50: ([0-9,]*)\) \(p95: ([0-9,]*)\) \(p99: ([0-9,]*)\) \(max: ([0-9,]*)\)/) {
			print $lastReport;
			$lastReport = "";

			$op = $1;
			$p50 = $2;
			$p95 = $3;
			$p99 = $4;
			$max = $5;

			$p50 =~ s/,//g;
			$p95 =~ s/,//g;
			$p99 =~ s/,//g;
			$max =~ s/,//g;

			$lastReport  = "p50-$op\t_\t_\t$timestamp\t$p50\t_\n";
			$lastReport .= "p95-$op\t_\t_\t$timestamp\t$p95\tR\n";
			$lastReport .= "p99-$op\t_\t_\t$timestamp\t$p99\t_\n";
			$lastReport .= "max-$op\t_\t_\t$timestamp\t$max\t_\n";
		}

	}
	close(INPUT);
}

1;
