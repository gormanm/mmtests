sub extractReport() {
	my ($self, $reportDir) = @_;

	my $input = open_log("$reportDir/fio.log");
	while (<$input>) {
		my @elements;
		my $worker;

		@elements = split(/;/, $_);
		$worker = $elements[2];
		# Total read KB > 0?
		if ($elements[5] > 0) {
			print "kb/sec\t$worker\tread\t1\t$elements[44]\tR\n";
		}
		# Total written KB > 0?
		if ($elements[46] > 0) {
			print "kb/sec\t$worker\twrite\t1\t$elements[85]\tR\n";
		}
	}
	close($input);
}

1;
