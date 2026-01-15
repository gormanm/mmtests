sub parseNumactl {
	my ($numactl) = @_;
	my %cpu_node;

	open(INPUT, "gunzip -c $numactl|") || die("Failed to open numactl output $numactl");
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		next if $line !~ /^node ([0-9]*) cpus: (.*)/;

		my $node = $1;
		for my $cpu (split(/\s/, $2)) {
			$cpu_node{$cpu} = $node;
		}
	}
	close INPUT;

	return %cpu_node;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my %cpu_node = parseNumactl("$reportDir/../../numactl.txt.gz");

	my $nr_samples_local = 0;
	my $nr_samples_remote = 0;
	my $file = "$reportDir/saladfork-0.log.gz";
	open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
	while (<INPUT>) {
		if ($_ !~ /([0-9]+)\s+([0-9]+)\s+([.0-9]+)/) {
			next;
		}

		# cpuids in $line are zero-padded like 000, 001, 002 etc
		# cpuids in %cpu_node are not. We convert string -> int -> string to remove padding.
		my $parent_cpu = "" . int($1);
		my $child_cpu = "" . int($2);

		my $latency = $3;
		if ($cpu_node{$parent_cpu} == $cpu_node{$child_cpu}) {
			$nr_samples_local++;
			print "local\t_\t_\t$nr_samples_local\t$latency\tR\n";
		} else {
			$nr_samples_remote++;
			print "remote\t_\t_\t$nr_samples_remote\t$latency\t_\n";
		}
	}
	close INPUT;

	# An additional "syntethic" operation: ratio of local forks VS total
	my $nr_total = $nr_samples_local + $nr_samples_remote;
	my $rLocal;
	if ($nr_total == 0) {
		$rLocal = 0;
	} else {
		$rLocal = $nr_samples_local / $nr_total;
	}

	print "local_v_total\t_\t_\t1\t$rLocal\t_\n"
}
1;
