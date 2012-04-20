#!/usr/bin/perl
# The output format from memcachetest is a complete pain in the arse to
# parse as part of a reporting script. This converts the format into
# something useful

use strict;

my $threads;
my ($max90, $max95, $max99, $max);
my $min;
my $avg;
my $operation;
my $ops;

sub to_us($$$) {

	if ($_[1] eq "us") {
		return $_[0];
	} elsif ($_[1] eq "ms") {
		return $_[0] * 1000;
	} elsif ($_[1] eq "ns") {
		return $_[0] / 1000;
	} else {
		print("line: $_[2]\n");
		die "Unknown conversion unit for $_[1]";
	}
}

while (<>) {
	my $line = $_;
	if ($line =~ /^Average with ([0-9]+) threads/) {
		$threads = $1;
	}

	if ($line =~ /^([a-zA-Z]+) operations:/) {
		$operation=$1;
	}

	if ($line =~ /^\s+[0-9]/) {
		my @fields = split(/\s+/, $line);

		$ops = $fields[1];
		$min = to_us($fields[2], $fields[3], $line);
		$max = to_us($fields[4], $fields[5], $line);
		$avg = to_us($fields[6], $fields[7], $line);
		$max90 = to_us($fields[8], $fields[9], $line);
		$max95 = to_us($fields[10], $fields[11], $line);
		$max99 = to_us($fields[12], $fields[13], $line);

		print("$operation :: $threads :: $ops $avg :: $min $max90 $max95 $max99 $max\n");
	}
}
	
