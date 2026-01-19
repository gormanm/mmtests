sub sort_unique {
	foreach my $array (@_) {
		my %tmp;
		foreach my $elm (@$array) {
			$tmp{$elm} = 1;
		}
		@$array = keys %tmp;
		@$array = sort {$a <=> $b} @$array;
	}
}

sub process_files {
	my ($self, $reportDir, $protocol, $size, $rate, $stream) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/$protocol-$size-$rate-$stream.*>) {
		my $send_tput = 0;
		my $recv_tput = 0;
		my $vals = 0;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;

			if ($line =~ /Summary Results:/) {
				$vals = 2 * $stream;
			}

			if ($vals && $line =~ /^\[ *[0-9]+\] +/) {
				$line =~ s/^\[ *[0-9]+\] +//;
				my @elements = split(/\s+/, $line);
				if ($line =~ /sender/) {
					$send_tput += $elements[4];
					$vals--;
				} elsif ($line =~ /receiver/) {
					$recv_tput += $elements[4];
					$vals--;
				}
				last if ! $vals;
			}
		}
		close(INPUT);

		$iteration++;
		print "send\t$size\t$rate-$stream\t$iteration\t$send_tput\t_\n";
		print "recv\t$size\t$rate-$stream\t$iteration\t$recv_tput\t_\n";
	}
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	open (INPUT, "$reportDir/protocols");
	my $protocol = <INPUT>;
	chomp($protocol);
	close(INPUT);

	my (@sizes, @rates, @streams);
	my @files = <$reportDir/$protocol-*.1>;
	foreach my $file (@files) {
		$file =~ s/.*\///;
		my @elements = split (/-/, $file);
		push @sizes, $elements[1];
		push @rates, $elements[2];
		$elements[3] =~ s/\.1$//;
		push @streams, $elements[3];
	}
	sort_unique(\@sizes, \@rates, \@streams);

	foreach my $size (@sizes) {
		foreach my $rate (@rates) {
			foreach my $stream (@streams) {
				process_files($self, $reportDir, $protocol,
					      $size, $rate, $stream);
			}
		}
	}
}

1;
