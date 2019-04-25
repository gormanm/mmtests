#!/usr/bin/perl
# This reads trace-cmd report for a function_graph plugin output and prints
# the frequency of a given function

use FindBin qw($Bin);
use lib "$Bin/lib/";

use MMTests::Stat;
use strict;

die if ($ARGV[0] eq "");
my $func = $ARGV[0];

my $indent = 0;
my $sample;
my $raw_sample;
my %sample_freq;
my %sample_latencies;
my %min_latency;
my %max_latency;
my %min_sample;
my %max_sample;
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
		$raw_sample = "$line\n";
		$raw_sample =~ s/\[.*funcgraph_//;
		$indent++;
		$start = $line;
		next;
	}
	next      if $indent == 0;
	$indent++ if $line =~ /\{$/;

	# Record just the stack trace
	my $trace = $line;
	$trace =~ s/\[.*\|//;
	$sample .= "$trace\n";

	# Record a sample without timestamps
	$trace = $line;
	$trace =~ s/\[.*funcgraph_//;
	$raw_sample .= "$trace\n";

	if ($line =~ /\}$/) {
		$indent--;
		if ($indent == 0) {
			$sample_freq{$sample}++;
			if ($line =~ /.* ([0-9.]+) us\s*\|/) {
				push @{$sample_latencies{$sample}}, $1;
				if (!defined $min_latency{$sample} || $1 < $min_latency{$sample}) {
					$min_latency{$sample} = $1;
					$min_sample{$sample} = $raw_sample;
				}

				if (!defined $max_latency{$sample} || $1 > $max_latency{$sample}) {
					$max_latency{$sample} = $1;
					$max_sample{$sample} = $raw_sample;
				}
			}
		}
	}
}

foreach my $trace (sort {$sample_freq{$b} <=> $sample_freq{$a}} keys %sample_freq) {
	my @latencies = @{$sample_latencies{$trace}};
	printf "SAMPLE occurred %4d times, min: %8.4fus mean: %8.4fus max: %8.4fus\n",
			$sample_freq{$trace},
			calc_min(\@latencies),
			calc_amean(\@latencies),
			calc_max(\@latencies);
	printf "Comparing samples with      min:%8.4fus max:%8.4fus\n", $min_latency{$trace}, $max_latency{$trace};
	# print "$trace\n";
	# print "Minimum latency: $min_latency{$trace}\n$min_sample{$trace}\n";
	# print "Maximum latency: $max_latency{$trace}\n$max_sample{$trace}\n";

	# Output comparison of min/max latency by line
	my @min_lines = split /\n/, $min_sample{$trace};
	my @max_lines = split /\n/, $max_sample{$trace};

	for (my $i = 0; $i < $#min_lines; $i++) {
		my ($min_timestamp, $min_trace) = split /\|/, $min_lines[$i];
		my ($max_timestamp, $max_trace) = split /\|/, $max_lines[$i];

		$min_timestamp =~ s/^\s+//;
		$max_timestamp =~ s/^\s+//;
		my @min_elements = split /\s+/, $min_timestamp;
		my @max_elements = split /\s+/, $max_timestamp;

		$min_timestamp = $min_elements[2];
		if ($min_timestamp !~ /[0-9]+/) {
			$min_timestamp = $min_elements[3];
		}
		$max_timestamp = $max_elements[2];
		if ($max_timestamp !~ /[0-9]+/) {
			$max_timestamp = $max_elements[3];
		}
		my $us = "  ";
		if ($min_timestamp eq "") {
			$min_timestamp = sprintf "%10s", " ";
		} else {
			$min_timestamp = sprintf "%10.4f", $min_timestamp;
			$us = "us";
		}
		if ($max_timestamp eq "") {
			$max_timestamp = sprintf "%10s", " ";
		} else {
			$max_timestamp = sprintf "%10.4f", $max_timestamp;
			$us = "us";

			if ($min_timestamp eq "" || $max_timestamp > $min_timestamp) {
				$us = "**";
			}
		}


		printf "%15s %8s %10s %10s %s | %s\n",
					$min_elements[0],
					$min_elements[1],
					$min_timestamp,
					$max_timestamp,
					$us,
					$min_trace;
	}
	# print "\nIndividual latencies: @latencies\n";
}
