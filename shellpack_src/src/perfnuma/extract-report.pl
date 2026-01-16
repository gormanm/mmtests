sub extractReport($$) {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @convergances;

	my @files = <$reportDir/*-1.log>;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		my $filename = $split[-1];
		$filename =~ s/-[0-9]+.log//;
		push @convergances, $filename;
	}
	@convergances = sort { $a cmp $b } @convergances;

	# Extract timing information
	foreach my $convergance (@convergances) {
		my $iteration = 0;

		my @files = <$reportDir/$convergance-*>;
		foreach my $file (@files) {
			$convergance =~ s/_converge//;
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /\s+([0-9.]+), secs,\s+NUMA-convergence-latency/) {
					$iteration++;
					print "converged-$convergance\t_\t_\t$iteration\t$1\tR\n";
				}
				if ($line =~ /\s+([0-9.]+), GB\/sec,\s+thread-speed/) {
					$iteration++;
					print "threadspeed-$convergance\t_\t_\t$iteration\t$1\t_\n";
				}
				if ($line =~ /\s+([0-9.]+), GB\/sec,\s+total-speed/) {
					$iteration++;
					print "totalspeed-$convergance\t_\t_\t$iteration\t$1\t_\n";
				}
			}
			close(INPUT);
			$iteration++;
		}
	}

	my @ops;
	foreach my $heading ("converged", "threadspeed", "totalspeed") {
		foreach my $convergance (@convergances) {
			push @ops, "$heading-$convergance";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
