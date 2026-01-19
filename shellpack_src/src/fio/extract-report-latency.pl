sub extractReport() {
	my ($self, $reportDir) = @_;
	my $seen_read = 0;
	my $seen_write = 0;

	my @files = <$reportDir/fio_lat.*.log*>;
	foreach my $file (@files) {
		my $nr_samples = 0;
		my $time;
		my $lat;
		my $dir;
		my $size;

		my $input = open_log($file);
		while (<$input>) {
			($time, $lat, $dir, $size) = split(/, /, $_);
			if ($dir == 0) {
				$dir = "read";
				$seen_read = 1;
			} elsif ($dir == 1) {
				$dir = "write";
				$seen_write = 1;
			} else {
				next;
			}
			$nr_samples++;
			$time /= 1000;
			print "latency-$dir\t_\t_\t$time\t$lat\t_\n";
		}
		close($input);
	}
}

1;
