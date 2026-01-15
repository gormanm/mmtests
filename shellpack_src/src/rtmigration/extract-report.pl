sub extractReport($$) {
	my ($self, $reportDir) = @_;
	my $nr_threads = 0;
	my $reading_samples = 0;

	my %samples;
	my %prios;

	my $input = open_log("$reportDir/rtmigration.log");
	while (!eof($input)) {
		my $line = <$input>;

		# Read number of tasks
		if ($line =~ /^Iter:/) {
			my @elements = split(/\s+/, $line);
			$nr_threads = $#elements;
			$reading_samples = 1;
			next;
		}

		# Read sample
		if ($reading_samples && $line =~ /^\s+[0-9]+:/) {
			$line =~ s/^\s+//;
			my @elements = split(/\s+/, $line);
			shift @elements;
			for (my $i = 0; $i < $nr_threads; $i++) {
				push @{$samples{$i}}, $elements[$i];
			}
			next;
		}

		# Read start of summary
		if ($line =~ /^Parent pid:/) {
			$reading_samples = 0;
		}

		# Read priorities
		if (!$reading_samples && $line =~ /^ Task ([0-9]+) \(prio ([0-9]+)\)/) {
			$prios{$1} = $2;
		}
	}
	close($input);

	for (my $i = 0; $i < $nr_threads; $i++) {
		my $nr_samples = 0;
		foreach my $sample (@{$samples{$i}}) {
			$nr_samples++;
			print "task-$i-p$prios{$i}\t_\t_\t$nr_samples\t$sample\t_\n";
		}
	}
}
1;
