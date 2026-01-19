sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = discover_scaling_parameters($reportDir, "threads-", ".log.gz");;

	foreach my $client (@clients) {
		my @local;
		my @remote;
		my @faults;
		my $uncertain = 0;

		my $input = open_log("$reportDir/threads-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /^fault/) {
				my $size;

				my @elements = split(/\s+/, $line);
				if ($elements[2] eq "base") {
					$size = 0;
				} else {
					$size = 1;
				}

				$faults[$size]++;
				if ($elements[5] == 1) {
					$local[$size]++;
				} elsif ($elements[5] == 0) {
					$remote[$size]++;
				} else {
					$uncertain++;
				}
			}
		}
		close $input;

		if ($faults[0] + $faults[1] != 0) {
			print "local-base\t$client\t_\t1\t" .  ($faults[0]  == 0 ? 0 : $local[0]  * 100 / $faults[0]) . "\t_";
			print "local-huge\t$client\t_\t1\t" .  ($faults[1]  == 0 ? 0 : $local[1]  * 100 / $faults[1]) . "\t_";
			print "remote-base\t$client\t_\t1\t" . ($faults[0]  == 0 ? 0 : $remote[0] * 100 / $faults[0]) . "\t_";
			print "remote-huge\t$client\t_\t1\t" . ($faults[1]  == 0 ? 0 : $remote[1] * 100 / $faults[1]) . "\t_";
		} else {
			$self->addData("local-none-$client", 0, -1);
		}
	}
}

1;
