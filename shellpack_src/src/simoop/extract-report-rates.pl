sub extractReport() {
	my ($self, $reportDir) = @_;

	my $reading = 0;
	my $timestamp;
	open(INPUT, "$reportDir/simoop.log") || die "Failed to open simoop.log";
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		chomp($line);

		if ($line =~ /^Warmup complete/) {
			$reading = 1;
		}
		next if !$reading;

		if ($line =~ /Run time: ([0-9]*) seconds/) {
			$timestamp = $1;
			next;
		}

		if ($line =~ /([a-zA-Z ]*) rate = ([0-9.]*)\/sec/) {
			my $op = $1;
			my $rate = $2;
			$op =~ s/alloc stall/stall/;
			if ($rate > 0) {
				print "$op\t_\t_\t$timestamp\t$rate\t_\n";
			}
		}

	}
	close(INPUT);
}

1;
