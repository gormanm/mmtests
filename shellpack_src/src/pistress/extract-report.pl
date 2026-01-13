sub extractReport($$) {
	my ($self, $reportDir) = @_;
	my @clients = discover_scaling_parameters($reportDir, "pistress-", ".log");
	my $nr_samples = 0;

	foreach my $client (@clients) {
		my $file = "$reportDir/pistress-$client.status";

		if (!open(INPUT, $file)) {
			$nr_samples++;
			print("failures\t$client\t$_\t$nr_samples\t1\t_\n");
			next;
		}

		while (!eof(INPUT)) {
			my $line = <INPUT>;
			chomp($line);
			$nr_samples++;
			print("failures\t$client\t$_\t$nr_samples\t$line\t_\n");
		}
		close(INPUT);
	}
}

1;
