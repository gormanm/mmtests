my %status_code = (
	"exit=exited"	=> 0,
	"exit=signaled"	=> 10,
	"exit=stopped"	=> 20,
	"exit=unknown"	=> 30,
);

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @collections;
	foreach my $file (<$reportDir/benchlog-*>) {
		my @split = split /\//, $file;
		$split[-1] =~ s/^benchlog-//;
		push @collections, $split[-1];
	}
	sort @collections;

	foreach my $collection (@collections) {
		# Parse results run runltp
		if (-e "$reportDir/runltp-$collection") {
			open(INPUT, "$reportDir/runltp-$collection") || die("Failed to open $reportDir/runltp-$collection\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;

				next if $line !~ /^tag=/;
				my @split = split /\s+/, $line;
				$split[0] =~ s/^tag=//;
				$split[4] =~ s/stat=//;
	
				die if !defined $status_code{$split[3]};
				$split[4] = 0 if ($status_code{$split[3]} == 0 && $split[4] == 32);
				my $val =  $split[3] + $split[4];
				print "$collection-$split[0]\t_\t_\t1\t$val\t_\n";
			}
			close(INPUT);
		} else {
			open(INPUT, "$reportDir/benchlog-$collection") || die("Failed to open $reportDir/benchlog-$collection\n");
			my $reading = 0;
			my $val = -1;

			while (!eof(INPUT)) {
				my $line = <INPUT>;
				if (!$reading) {
					if ($line =~ /^Summary:/) {
						$reading = 1;
						$val = 0;
					}
					next;
				}

				next if ($line =~ /^passed/);
				next if ($line =~ /^skipped/);
				next if ($line =~ /^broken/);
				my @split = split /\s+/, $line;
				$val += $split[1];
			}
			close(INPUT);
			print "$collection\t_\t_\t1\t$val\t_\n";
		}

		close(INPUT);
	}
}

1;
