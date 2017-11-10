#!/usr/bin/perl
# This reads trace-cmd report for a function_graph plugin output and prints
# the frequency of a given function

use FindBin qw($Bin);
use lib "$Bin/lib/";

use VMR::Stat;
use strict;

die if ($ARGV[0] eq "");
my $func = $ARGV[0];

my $indent = 0;
my $sample;
my %sample_freq;
my %sample_latencies;
my $start;

while (!eof(STDIN)) {
	my $line = <STDIN>;
	chomp($line);
	if ($line =~ /^\s+(.*)\[.*$func\(\) \{/) {
		if ($indent > 0) {
			print "Resetting due to uncertainity indent $indent\n";
			print "LAST: $start\n";
			print "THIS: $line\n";
			$indent = 0;
		}
		$sample = "proc $1\n$line\n";
		$sample =~ s/\[.*\|//;
		$indent++;
		$start = $line;
		next;
	}
	next      if $indent == 0;
	$indent++ if $line =~ /\{$/;

	my $trace = $line;
	$trace =~ s/\[.*\|//;
	$sample .= "$trace\n";
	if ($line =~ /\}$/) {
		$indent--;
		if ($indent == 0) {
			$sample_freq{$sample}++;
			if ($line =~ /.* ([0-9.]+) us\s*\|/) {
				push @{$sample_latencies{$sample}}, $1;
			}
		}
	}
}

foreach my $trace (sort {$sample_freq{$b} <=> $sample_freq{$a}} keys %sample_freq) {
	my @latencies = @{$sample_latencies{$trace}};
	printf "SAMPLE occurred %4d times, min: %8.4fus mean: %8.4fus max: %8.4fus\n",
			$sample_freq{$trace},
			calc_min(@latencies),
			calc_mean(@latencies),
			calc_max(@latencies);
	print "$trace\n";
}
