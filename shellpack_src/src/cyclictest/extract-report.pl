sub parseResults($$) {
	my ($self, $reportDir) = @_;
	my $value;

	my $input = open_log("cyclictest-histogram.log") || die "Failed to open $reportDir/cyclictest-histogram.log";
	while (<$input>) {
		my $line = $_;
		my $op;
		if ($line =~ /^# (...) Latencies: (.*)/) {
			$op = $1 . "Lat";
			$value = $2;
		} elsif ($line =~ /^# Histogram Overflows: (.*)/) {
			$op = "Overflow";
			$value = $1;
		} else {
			next;
		}

		my @valueArr = split(/ /, $value);
		for (my $cpu = 0; $cpu < $#valueArr; $cpu++) {
			$valueArr[$cpu] =~ s/^0+//;
			print "${op}\t$cpu\t_\t0\t$valueArr[$cpu]\t_\n";
		}
	}
	close $input;
}

1;
