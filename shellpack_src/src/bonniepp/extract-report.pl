sub extractReport($$) {
	my ($self, $reportDir) = @_;
	if (! -e "$file" && ! -e "$file.gz") {
		$file =~ s/bonnie\/logs/bonniepp\/logs/;
	}

	my %ops = (
		"pc" => "SeqOut char",
		"wr" => "SeqOut block",
		"rw" => "SeqOut rewrite",
		"gc" => "SeqIn char",
		"rd" => "SeqIn block",
		"sk" => "Random seeks",
		"cs" => "SeqCreate create",
		"ss" => "SeqCreate read",
		"ds" => "SeqCreate del",
		"cr" => "RandCreate create",
		"sr" => "RandCreate read",
		"dr" => "RandCreate del"
	);

	my %nrSamples;

	my $file = "$reportDir/bonnie-detail";
	my $input = open_log("$file") || die("Failed to open $file\n");
	while (<$input>) {
		chomp;
		my $line = $_;
		my @elements = split(/ /, $line);

		if (defined($ops{$elements[0]})) {
			$nrSamples{$elements[0]}++;
			my $ratio = "_";
			$ratio = "R" if $ops{$elements[0]} =~ /.*_block$/;
			print "$ops{$elements[0]}\t_\t_\t$nrSamples{$elements[0]}\t$elements[1]\t_\n";
		}
	}
	close($input);
}

1;
