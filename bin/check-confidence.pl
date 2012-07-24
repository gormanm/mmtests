#!/usr/bin/perl
# Read a series of values from stdin and determine if after filtering that
# we are confident of the results

use FindBin qw($Bin);
use lib "$Bin/lib/";

use Getopt::Long;
use Pod::Usage;
use VMR::Report;
use VMR::Stat;
use IO::File;

use strict;

my $opt_verbose;
my $opt_confidence_level = 95;
my $opt_limit = 2;
my $opt_min_samples = 3;
my $opt_print_mean;
my $opt_print_stddev;

# Get options
GetOptions(
        'verbose|v'          => \$opt_verbose,
	'confidence-level=s' => \$opt_confidence_level,
	'limit=s'            => \$opt_limit,
	'min-samples=s'      => \$opt_min_samples,
	'print-mean'         => \$opt_print_mean,
	'print-stddev'       => \$opt_print_stddev,
        );
setVerbose if $opt_verbose;

my @results;
my $nr_samples;

# Read samples from stdin
while ( $results[$nr_samples] = <>) {
	chomp($results[$nr_samples]);
	printVerbose("Read sample $results[$nr_samples]\n");
	$nr_samples++;
}

my $sample;
my $mean = calc_mean(@results);
my $stddev = calc_stddev(@results);
my $conf = calc_confidence_interval_lower($opt_confidence_level, @results);
my $limit = $mean * $opt_limit / 100;
my $conf_delta = $mean - $conf;
my $usable_samples = $nr_samples;
printVerbose("Initial stats\n");
printVerbose("  o mean      = $mean\n");
printVerbose("  o stddev    = $stddev\n");
printVerbose("  o con $opt_confidence_level    = $conf\n");
printVerbose("  o limit     = $limit\n");
printVerbose("  o con delta = $conf_delta\n");
printVerbose("Start\n");

for ($sample = 0; $sample <= $nr_samples; $sample++) {

CONF_LOOP:
	while ($conf_delta > $limit) {
		if ($usable_samples == $opt_min_samples) {
			printVerbose("Minimum number of samples reached\n");
			exit -1;
		}
		printVerbose("  o confidence delta $conf_delta outside $limit\n");
		my $max_delta = -1;
		my $max_index = -1;
		for ($sample = 0; $sample <= $nr_samples; $sample++) {
			if (! defined $results[$sample]) {
				next;
			}
			my $delta = abs(@results[$sample] - $mean);
			if ($delta > $max_delta) {
				$max_delta = $delta;
				$max_index = $sample;
			}
		}

		printVerbose("  o dropping index $max_index result $results[$max_index]\n");
		undef $results[$max_index];
		$usable_samples--;

		$mean = calc_mean(@results);
		$stddev = calc_stddev(@results);
		$conf = calc_confidence_interval_lower($opt_confidence_level, @results);
		$limit = $mean * $opt_limit / 100;
		$conf_delta = $mean - $conf;

		printVerbose("  o recalc mean   = $mean\n");
		printVerbose("  o recalc stddev = $stddev\n");
		printVerbose("  o recalc con $opt_confidence_level = $conf\n");
		printVerbose("  o limit     = $limit\n");
		printVerbose("  o con delta = $conf_delta\n");
	}
}

printVerbose("confident\n");
if ($opt_print_mean) {
	print calc_mean(@results);
}
if ($opt_print_stddev) {
	print calc_stddev(@results);
}
exit 0;
