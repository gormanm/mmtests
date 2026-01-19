sub extractReport() {
	my ($self, $reportDir) = @_;

	open(INPUT, "$reportDir/pmqtest.log") || die("Failed to open data file\n");
	while (<INPUT>) {
		next if ($_ !~ /\#+([0-9]+) -> \#+([0-9]+), Min\s+([0-9]+), Cur\s+([0-9]+), Avg\s+([0-9]+), Max\s+([0-9]+)/);
		print("Min-$1->$2\t_\t_\t1\t$3\t_\n");
		print("Avg-$1->$2\t_\t_\t1\t$5\t_\n");
		print("Max-$1->$2\t_\t_\t1\t$6\t_\n");
	}
	close INPUT;
}

1;
