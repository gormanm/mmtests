sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport($$) {
	my ($self, $reportDir) = @_;
	my ($tp, $name);
	my $file_wk = "$reportDir/workloads";
	open(INPUT, "$file_wk") || die("Failed to open $file_wk\n");
	my @workloads = split(/ /, <INPUT>);
	$self->{_Workloads} = \@workloads;
	close(INPUT);

	my @threads;
	foreach my $wl (@workloads) {
		chomp($wl);
		my @files = <$reportDir/$wl-*.log>;
		foreach my $file (@files) {
			my @elements = split (/-/, $file);
			my $thr = $elements[-1];
			$thr =~ s/.log//;
			push @threads, $thr;
		}
	}
	@threads = sort {$a <=> $b} @threads;
	@threads = uniq(@threads);
	my %futexTypesSeen;

	foreach my $nthr (@threads) {
		foreach my $wl (@workloads) {
			my $file = "$reportDir/$wl-$nthr.log";
			my $futexType = "private";
			my $nr_samples = 0;

			my $input = open_log($file);
			while (<$input>) {
				my $line = $_;
				my @tmp = split(/\s+/, $line);

				if ($line =~ /shared/) {
					$futexType = "shared";
				}

				if ($line =~ /.*futexes:.* \[ ([0-9]+) ops\/sec.*/) {
					$tp = $1;
				} elsif ($line =~ /.*futex:.* \[ ([0-9]+) ops\/sec.*/) {
					$tp = $1;
				} elsif ($line =~ /.*: Requeued.* in ([0-9.]+) ms/) {
					$tp = $1;
				} elsif ($line =~ /.*: Awoke and Requeued.* in ([0-9.]+) ms/) {
					$tp = $1;
				} elsif ($line =~ /.*: Wokeup.* in ([0-9.]+) ms/) {
					$tp = $1;
				} elsif ($line =~ /.*: Avg per-thread latency.* in ([0-9.]+) ms/) {
					$tp = $1 * 1000; # better suits mmtests as usec.
				} else {
					next;
				}

				$futexTypesSeen{$futexType} = 1;
				$nr_samples++;
				print("$wl\t$futexType\t$nthr\t$nr_samples\t$tp\t_\n");
			}

			close $input;
		}
	}

	my @ops;
	foreach my $futexType (sort keys %futexTypesSeen) {
		foreach my $wl (@workloads) {
			foreach my $nthr (@threads) {
				push @ops, "$wl-$futexType-$nthr"
			}
		}
	}
	$self->{_Operations} = \@ops;
}

1;
