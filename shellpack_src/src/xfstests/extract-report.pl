sub extractReport() {
	my ($self, $reportDir) = @_;

	my $file = "$reportDir/xfstests-default.log";

	my %status;
	my @all_tests;

	open(INPUT, $file) || die("Failed to open $file\n");
	while (!eof(INPUT)) {
		my $line = <INPUT>;

		next if $line !~ /^([a-z]+\/[0-9a-z]+)\s(.*)/;

		my $xfstest = $1;
		my $results = $2;
		$results =~ s/([\s\.0-9a-z]*\[)?/\[/;

		my @elements = split /[\[\]]/, $results;
		next if $elements[5] =~ /^not run$/;

		$status{$xfstest} = 0;
		if ($elements[3] =~ /failed.*([0-9])+/) {
			$status{$xfstest} = $1;
		}
		push @all_tests, $xfstest;
	}

	foreach my $xfstest (@all_tests) {
		print "$xfstest\t_\t_\t1\t$status{$xfstest}\t_\n";
	}

	close(INPUT);
}

1;
