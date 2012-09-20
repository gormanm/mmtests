#!/usr/bin/perl
# This script reads an oprofile report as recorded by MM tests from STDIN and
# a vmlinux file on the command line. It summarises how much time is spent
# in each filename and lists how much time was spent in each function in that
# file. 
#
# Copyright Mel Gorman 2012
use strict;

my $vmlinux = $ARGV[0];
my $readingProfile;
my %fileMap;
my %fileList;
my %funcMap;
my %symbolMap;

if ($vmlinux eq "") {
	print("Specify vmlinux file\n");
	exit(-1);
}

open(NM, "nm $vmlinux|") || die("Failed to run nm");
while (!eof(NM)) {
	my @elements = split (/\s+/, <NM>);
	$symbolMap{$elements[2]} = $elements[0];
}
close NM;

while (<STDIN>) {
	my $line = $_;
	
	if ($line =~ /======= long report =========/) {
		$readingProfile = 1;
		next;
	}

	if ($line =~ /====== annotate ========/) {
		$readingProfile = 0;
		next;
	}

	if ($readingProfile && $line =~ /vmlinux/ ) {
		my @elements = split(/\s+/, $line);
		if ($elements[1] <= 0.01) {
			last;
		}

		open (ADDR, "addr2line -e $vmlinux $symbolMap{$elements[3]}|") || die ("Failed to run addr2line");
		my $location = <ADDR>;
		close ADDR;
		chomp $location;
		$location =~ s/:[0-9]+$//;
		$fileMap{$location} += $elements[1];
		$funcMap{$elements[4]} = $elements[1];

		my $buffer = sprintf("  %-58s %10s %10.4f\n", $elements[3], "", $elements[1]);
		$fileList{$location} .= $buffer;
	}
}

foreach my $loc (sort {$fileMap{$b} <=> $fileMap{$a} } keys %fileMap)
{
	printf "%-60s %10.4f\n", $loc, $fileMap{$loc};
	print $fileList{$loc};
}
