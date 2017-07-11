#!/usr/bin/perl

# Perform Welch's t-test for two samples x and y (e.g. testing
# hypothesis that µ_x equals µ_y)
# Input:
#  mean_x, stddev_x, m (mean, stddev, number of samples of sample x)
#  mean_y, stddev_y, n (mean, stddev, number of samples of sample y)
#  significance level

use FindBin qw($Bin);
use lib "$Bin/lib/";

use Getopt::Long;
use Pod::Usage;
use VMR::Report;
use VMR::Stat;
use IO::File;

use strict;

my $opt_verbose;
my $opt_significance_level = 1;

# Get options
GetOptions(
        'verbose|v'          => \$opt_verbose,
	'significance-level=s' => \$opt_significance_level,
        );
setVerbose if $opt_verbose;

my @args;
my $nr_args=0;

# Read arguments
while ( $args[$nr_args] = <>) {
	chomp($args[$nr_args]);
	printVerbose("Input args[$nr_args]: $args[$nr_args]\n");
	$nr_args++;
}

if ($nr_args < 7) {
	print "Input data insufficient\n";
	exit -1;
}

my $mx = @args[0];
my $sx = @args[1];
my $m = @args[2];
my $my = @args[3];
my $sy = @args[4];
my $n = @args[5];
my $alpha = @args[6];

print "mean_x: $mx, stddev_x: $sx, samples: $m\n";
print "mean_y: $my, stddev_y: $sy, samples: $n\n";
print "Testing H_0: µx=µy at significance level $alpha%: ";

my $rc = calc_welch_test($mx, $my, $sx, $sy, $m, $n, $alpha);
if ($rc == 1) {
    print "rejecting (assuming µx != µy)\n";
} else {
    print "Can't reject H_0\n";
}

exit 0;
