#!/usr/bin/perl
# extract-mmtests.pl - Extract results from an MM Tests directory
# 
# Different benchmark frameworks collect and report data differently. To
# analyse the data it is necessary to extract the raw performance figures.
# This program simplifies this task for this framework. At its most basic
# usage it takes a directory as a parameter and prints the most relevant
# metric of interest.
#
# Copyright: SUSE Labs, 2012
# Author:    Mel Gorman, 2012

use FindBin qw($Bin);
use lib "$Bin/lib";

use Getopt::Long;
use Pod::Usage;
use MMTests::Report;
use MMTests::Extract;
use MMTests::ExtractFactory;
use strict;

# Option variable
my ($opt_verbose);
my ($opt_help, $opt_manual);
my ($opt_reportDirectory, $opt_monitor);
my ($opt_printHeader, $opt_printPlot, $opt_printType, $opt_printJSON);
my ($opt_subheading, $opt_format);
my ($opt_name, $opt_benchmark, $opt_altreport);
GetOptions(
	'verbose|v'		=> \$opt_verbose,
	'help|h'		=> \$opt_help,
	'--format=s'		=> \$opt_format,
	'--print-type'		=> \$opt_printType,
	'--print-header'	=> \$opt_printHeader,
	'--print-plot'		=> \$opt_printPlot,
	'--print-json'		=> \$opt_printJSON,
	'--print-monitor=s'	=> \$opt_monitor,
	'--sub-heading=s'	=> \$opt_subheading,
	'n|name=s'		=> \$opt_name,
	'b|benchmark=s'		=> \$opt_benchmark,
	'a|altreport=s'		=> \$opt_altreport,
	'manual'		=> \$opt_manual,
	'directory|d=s'		=> \$opt_reportDirectory,
);
setVerbose if $opt_verbose;
pod2usage(-exitstatus => 0, -verbose => 0) if $opt_help;
pod2usage(-exitstatus => 0, -verbose => 2) if $opt_manual;

my ($reportDir);
$reportDir = "$opt_reportDirectory/$opt_name";

# Sanity check directory
if (! -d $reportDir) {
	printWarning("Report directory $reportDir does not exist or was not specified.");
	pod2usage(-exitstatus => -1, -verbose => 0);
}

sub exportJSON {
	my ($module, $benchmark, $name) = @_;
	require Cpanel::JSON::XS;
	my $json = Cpanel::JSON::XS->new();

	printVerbose("Exporting to JSON\n");

	$json->allow_blessed();
	$json->convert_blessed();

	print $json->encode($module);
}

# If monitors are requested, extract that and exit
if (defined $opt_monitor) {
	my $monitorFactory = MMTests::ExtractFactory->new();
	my $monitorModule;
	eval {
		$monitorModule = $monitorFactory->loadModule("monitor", $opt_monitor, $opt_name, $opt_subheading);
	} or do {
		printWarning("Failed to load module for monitor $opt_monitor\n$@");
		exit(-1);
	};

	my @iterdirs = <$reportDir/iter-*>;
	foreach my $iterdir (@iterdirs) {
		$monitorModule->extractReport($iterdir, "$opt_benchmark",
					      $opt_subheading);
		$monitorModule->nextIteration();
	}

	# Just print the type if asked
	if ($opt_printType) {
		$monitorModule->printDataType($opt_subheading);
		exit;
	}

	if ($opt_printPlot) {
		$monitorModule->printPlotHeaders() if $opt_printHeader;
		$monitorModule->printPlot($opt_subheading);
	} elsif ($opt_printJSON) {
		exportJSON($monitorModule, "$opt_benchmark", $opt_name);
	} else {
		$monitorModule->printReportTop();
		$monitorModule->printFieldHeaders() if $opt_printHeader;
		$monitorModule->printReport();
		$monitorModule->printReportBottom();
	}
	exit(0);
}

# Instantiate a handler of the requested type for the benchmark
my $extractFactory = MMTests::ExtractFactory->new();
my $extractModule;
eval {
	$extractModule = $extractFactory->loadModule("extract", "$opt_benchmark$opt_altreport", $opt_name, $opt_subheading);
} or do {
	printWarning("Failed to load module for benchmark $opt_benchmark$opt_altreport\n$@");
	exit(-1);
};

# Just print the type if asked
if ($opt_printType) {
	$extractModule->printDataType($opt_subheading);
	exit;
}

# Extract data from the benchmark itself and print whatever was requested
my @iterdirs = <$reportDir/iter-*>;
foreach my $iterdir (@iterdirs) {
	# Make a guess at the sub-directory name if one is not specified
	$iterdir = "$iterdir/$opt_benchmark";
	$extractModule->extractReport("$iterdir/logs");
	$extractModule->nextIteration();
}
if ($opt_printJSON) {
	exportJSON($extractModule, $opt_benchmark, $opt_name);
	exit;
}
$extractModule->printReportTop();
if ($opt_printPlot) {
	$extractModule->printPlotHeaders() if $opt_printHeader;
	$extractModule->printPlot($opt_subheading);
} else {
	$extractModule->printFieldHeaders() if $opt_printHeader;
	$extractModule->printReport();
}
$extractModule->printReportBottom();

# Below this line is help and manual page information
__END__
=head1 NAME

extract-mmtests.pl - Extract results from an MM Tests result directory

=head1 SYNOPSIS

extract-mmtest [options]

 Options:
 -d, --directory	Work log directory to extract data from
 -n, --name		Title for the series if tests given to run-mmtests.sh
 -b, --benchmark	Benchmark to extract data for
 -v, --verbose		Verbose output
 --format=text		Output format, valid are html or text (default)
 --print-type		Print benchmark metric type
 --print-header		Print a header
 --print-monitor	Print information related to a monitor
 --print-plot		Print in a format suitable for consumption by gnuplot
 --print-json		Print extracted data in JSON format
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

=item B<--format>

Output format for the report. Valid options are html and text. By default
the formatting is in plain text.

=item B<--print-type>

Print what type of metric the benchmark produces.

=item B<--print-header>

Print a header that briefly describes what each of the fields are.

=item B<--print-monitor>

MM Tests gathers additional information with monitors that can also be
extracted. Some are always available and are coarse such as how long
the tests run. Others have to be enabled from the config file before
the benchmark runs.

=item B<--print-plot>

Print data suitable for plotting with. The exact format this takes will
depend on the type of data being extracted. It may be necessary to specify
--sub-heading.

=item B<--print-json>

Print extracted data in JSON format.

=item B<--sub-heading>

For certain operation a sub-heading is required. For example, when extracting
CPUTime data and plotting it, it is necessary to specify if User, Sys,
Elapsed or CPU time is being plotted. In general --print-header can be
used to get a lot of the headings to pass to --sub-heading.

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
