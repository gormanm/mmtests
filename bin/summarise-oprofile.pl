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
my %percentageMap;
my %sampleMap;
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

		my $offset = 0;
		if ($elements[3] =~ /^vmlinux/) {
			$offset = 1;
		}

		open (ADDR, "addr2line -e $vmlinux $symbolMap{$elements[3+$offset]}|") || die ("Failed to run addr2line");
		my $location = <ADDR>;
		close ADDR;
		chomp $location;
		$location =~ s/:[0-9]+$//;
		$sampleMap{$location} += $elements[0];
		$percentageMap{$location} += $elements[1];
		$funcMap{$elements[3+$offset]} = $elements[1];

		my $buffer = sprintf("  %-66s %8s %6.3f%% %8d\n", $elements[3+$offset], "", $elements[1], $elements[0]);
		$fileList{$location} .= $buffer;
	}
}

foreach my $loc (sort {$percentageMap{$b} <=> $percentageMap{$a} } keys %percentageMap)
{
	printf "%-66s %8.4f %8d\n", $loc, $percentageMap{$loc}, $sampleMap{$loc};
	print $fileList{$loc};
}
