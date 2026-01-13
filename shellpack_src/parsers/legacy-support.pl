# Taken from old mmtests extraction support
sub open_log($) {
	my ($file) = @_;
	my $fh;

	$file =~ s/\.gz$//;
	$file =~ s/\.xz$//;
	if (-e "$file.gz") {
		open($fh, "gunzip -c $file.gz|") || die("Failed to open $file.gz: $!\n");
	} elsif (-e "$file.xz") {
		open($fh, "unxz -c $file.xz|") || die("Failed to open $file.xz: $!\n");
	} elsif (-e $file) {
		open($fh, $file) || die("Failed to open $file: $!\n") || die("Failed to open $file");
	}

	return $fh;
}

sub discover_scaling_parameters {
	my ($reportDir, $prefix, $suffix, $infix) = @_;
	my @scaling;

	my @files = <$reportDir/$prefix*$suffix>;
	foreach my $file (<$reportDir/$prefix*$suffix>) {
		$file =~ s/.*\/$prefix//;

		if ($suffix ne "") {
			$file =~ s/$suffix$//;
		}

		if ($infix ne "") {
			$file =~ s/$infix//;
		}

		push @scaling, $file;
	}

	@scaling = sort { $a <=> $b } @scaling;
	return @scaling;
}

1;
