sub extractReport($$$) {
	my ($self, $reportDir) = @_;

	my @jobnames;
	foreach my $file (<$reportDir/results/replayed_*_startup>) {
		$file =~ s/.*replayed_//;
		$file =~ s/_startup$//;
		$file =~ s/_startup.txt$//;
		push @jobnames, $file;
	}
	@jobnames = sort { $a <=> $b } @jobnames;

	foreach my $jobname (@jobnames) {
		my $reading = 0;

		my @schedulers;
		foreach my $file (<$reportDir/results/replayed_$jobname\_startup/repetition0/*-0r0w-seq-single_times.txt>) {
			$file =~ s/.*\/repetition0\///;
			$file =~ s/-0r0w-seq-single_times.txt$//;
			push @schedulers, $file;
		}
		@schedulers = sort { $a <=> $b } @schedulers;

		# Scheduler info is extracted but not used. If its
		# planned in the future that one benchmark run
		# switches between I/O schedulers this extraction
		# needs to be adapted.
		foreach my $scheduler (@schedulers) {
			my @patterns = qw{0r0w-seq 5r5w-seq 10r0w-seq};

			# Now extract data from
			# $scheduler-$pattern-single_times.txt (not
			# using $scheduler-$pattern-lat_thr_stat.txt
			# at the moment).
			foreach my $pattern (@patterns) {
				my $nr_samples=0;
				open INPUT,
				"$reportDir/results/replayed_$jobname\_startup/repetition0/$scheduler-$pattern-single_times.txt"
				|| die "Failed to find time data file
				for $jobname\n";

				while (!eof(INPUT)) {
					my $line = <INPUT>;
					chomp($line);
					$line =~ s/^\s+//;
					$nr_samples++;
					print "$jobname\t$pattern\t_\t$nr_samples\t$line\t_\n";
				}
				close INPUT;
			}
		}
	}
}
1;
