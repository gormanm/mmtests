#!/usr/bin/perl
# compare-mmtests.pl - Compare results from an MM Tests directory
# 
# Copyright: SUSE Labs, 2012
# Author:    Mel Gorman, 2012

use FindBin qw($Bin);
use lib "$Bin/lib";

use Getopt::Long;
use Pod::Usage;
use MMTests::Report;
use MMTests::Stat;
use MMTests::Compare;
use MMTests::CompareFactory;
use MMTests::Extract;
use MMTests::ExtractFactory;
use strict;

# Option variable
my ($opt_verbose);
my ($opt_help, $opt_manual);
my ($opt_reportDirectory);
my ($opt_printHeader, $opt_printRatio, $opt_printSignificance);
my ($opt_subheading, $opt_format);
my ($opt_names, $opt_benchmark);
my ($opt_monitor, $opt_hideCompare);
my ($opt_JSONExport);
GetOptions(
	'verbose|v'		=> \$opt_verbose,
	'help|h'		=> \$opt_help,
	'--print-header'	=> \$opt_printHeader,
	'--print-ratio'		=> \$opt_printRatio,
	'--print-significance'	=> \$opt_printSignificance,
	'--print-monitor=s'	=> \$opt_monitor,
	'--no-compare'		=> \$opt_hideCompare,
	'--sub-heading=s'	=> \$opt_subheading,
	'--format=s'		=> \$opt_format,
	'--json-export'		=> \$opt_JSONExport,
	'n|names=s'		=> \$opt_names,
	'b|benchmark=s'		=> \$opt_benchmark,
	'manual'		=> \$opt_manual,
	'directory|d=s'		=> \$opt_reportDirectory,
);
setVerbose if $opt_verbose;
pod2usage(-exitstatus => 0, -verbose => 0) if $opt_help;
pod2usage(-exitstatus => 0, -verbose => 2) if $opt_manual;

# Sanity check directory
if (! -d $opt_reportDirectory) {
	printWarning("Report directory $opt_reportDirectory does not exist or was not specified.");
	pod2usage(-exitstatus => -1, -verbose => 0);
}

my @extractModules;
my $nrModules = 0;
my $extractFactory = MMTests::ExtractFactory->new();
if (!defined($opt_monitor)) {
	# Instantiate extract handlers for the requested type for the benchmark
	for my $name (split /,/, $opt_names) {
		printVerbose("Loading extract $opt_benchmark $name\n");
		eval {
			my $reportDirectory = "$opt_reportDirectory/$name";
			my @iterdirs = <"$reportDirectory/iter-*">;

			$extractModules[$nrModules] = $extractFactory->loadModule("extract", $opt_benchmark, $name, $opt_subheading);
			foreach my $iterdir (@iterdirs) {
				$iterdir = "$iterdir/$opt_benchmark";
				$extractModules[$nrModules]->extractReport("$iterdir/logs");
				$extractModules[$nrModules]->nextIteration();
			}
			if ($opt_printRatio) {
				$extractModules[$nrModules++]->extractRatioSummary($opt_subheading);
			} else {
				$extractModules[$nrModules++]->extractSummary($opt_subheading);
			}
		} or do {
			printWarning("Failed to load module for benchmark $opt_benchmark: $name\n$@");
			$#extractModules -= 1;
		}
	};
} else {
	$opt_hideCompare = 1;
	for my $name (split /,/, $opt_names) {
		printVerbose("Loading extract $opt_benchmark $name\n");
		eval {
			my $reportDirectory = "$opt_reportDirectory/$name";
			my @iterdirs = <$reportDirectory/iter-*>;
			$extractModules[$nrModules] = $extractFactory->loadModule("monitor", $opt_monitor, $name, $opt_subheading);
			foreach my $iterdir (@iterdirs) {
				$extractModules[$nrModules]->extractReport($iterdir, $opt_benchmark, $opt_subheading, 1);
				$extractModules[$nrModules]->nextIteration();
			}
			$extractModules[$nrModules++]->extractSummary($opt_subheading);
		} or do {
			printWarning("Failed to load module for benchmark $opt_benchmark, $name\n$@");
			$#extractModules -= 1;
		}
	};
}
	
printVerbose("Loaded $nrModules extract modules\n");

# Instantiate comparison for the requested type for the benchmark
my $compareFactory = MMTests::CompareFactory->new();
my $compareModule;
printVerbose("Loading compare $opt_benchmark\n");
eval {
	$compareModule = $compareFactory->loadModule($opt_format, \@extractModules);
} or do {
	printWarning("Failed to compare module for benchmark $opt_benchmark\n$@");
	exit(-1);
};
printVerbose("Loaded compare module\n");

$compareModule->extractComparison($opt_printRatio, !$opt_hideCompare);

$compareModule->printComparison($opt_printRatio, $opt_printSignificance, $opt_subheading);

if ($opt_JSONExport && $opt_benchmark) {
	my $fname = "$opt_reportDirectory/$opt_benchmark.json";
	$compareModule->saveJSONExport($fname);
	# $compareModule might occupy more than 50% of memory. In such case
	# forking to call gzip will result in ENOMEM from clone(2).
	# We need to start afresh with a new sheet of memory using exec.
	exec "gzip -f $fname";
}
# The branch above terminates the program. Don't put any code below this line.
exit(0)

# Below this line is help and manual page information
__END__
=head1 NAME

compare-mmtests.pl - Compare results from an MM Tests result directory

=head1 SYNOPSIS

compare-mmtests.pl [options]

 Options:
 -d, --directory	Work log directory to extract data from
 -n, --names		Titles for the series if tests given to run-mmtests.sh
 -b, --benchmark	Benchmark to extract data for
 -v, --verbose		Verbose output
 --format		Output format
 --json-export		Saves comparison data in JSON format (gzip'ed)
 --print-header		Print a header
 --print-ratio		Print relative comparison instead of absolute values
 --print-monitor=s	Print comparison based on specified monitor
 --sub-heading		Analyse just a sub-heading of the data, see manual page
 --manual		Print manual page
 --help			Print help message

=head1 OPTIONS

=over 8

=item B<-d, --directory>

Specifies the directory containing results generated by MM Tests.

=item B<n, --name>

The name of the test series as supplied to run-mmtests.sh. This might have
been a kernel version for example.

=item B<b, --benchmark>

The name of the benchmark to extract data from. For example, if a given
test ran kernbench and sysbench and the sysbench results were required
then specify "-b sysbench".

=item B<R, --R-summary>

Path to a file containing table with summary produced by R, as produced
by compare-mmtests-R.sh. Summarization by perl modules is skipped in the
presence of R-based results.

=item B<--format>

Output format for the report. Valid options are html and text. By default
the formatting is in plain text.

=item B<--json-export>

Saves comparison data in a compressed JSON file inside the current
directory. The exported file is named <benchmark>.json.gz, where <benchmark>
is the value of the --benchmark option flag.

=item B<--print-header>

Print a header that briefly describes what each of the fields are.

=item B<--print-ratio>

Print values as ratios relative to baseline instead of absolute values

=item B<--print-monitor>

Print comparison based on specified monitor.

=item B<--sub-heading>

For certain operation a sub-heading is required. For example, when extracting
CPUTime data and plotting it, it is necessary to specify if User, Sys,
Elapsed or CPU time is being plotted. In general --print-header can be
used to get a lot of the headings to pass to --sub-heading.

=item B<--no-compare>

It does not always make sense to use the default comparison operators. Use
this switch to hide them if they are deemed to be unnecessary. This can be
the case when comparing ratios for example or many of the monitors.

=item B<--help>

Print a help message and exit

=item B<-v, --verbose>

Be verbose in the output.

=back

=head1 DESCRIPTION

No detailed description available.

=head1 AUTHOD

Written by Mel Gorman <mgorman@suse.de>

=head1 REPORTING BUGS

Report bugs to the author.

=cut
