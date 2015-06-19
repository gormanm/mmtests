#!/usr/bin/perl
# This script is a combined perl and systemtap script to collect stats on
# slab activity. The intention is to build a picture of how slab-intensive
# a workload is and what the sources are
#
# Copyright Mel Gorman <mgorman@suse.de> 2015

use File::Temp qw/mkstemp/;
use File::Find;
use FindBin qw($Bin);
use Getopt::Long;
use strict;

# Handle cleanup of temp files
my $stappid;
my ($handle, $stapscript) = mkstemp("/tmp/stapdXXXXX");
sub cleanup {
	if (defined($stappid)) {
		kill INT => $stappid;
	}
	unlink($stapscript);
}
sub sigint_handler {
	close(STAP);
	cleanup();
	exit(0);
}
$SIG{INT} = "sigint_handler";

my $monitorInterval = $ENV{"MONITOR_UPDATE_FREQUENCY"};
if ($monitorInterval == 0) {
	$monitorInterval = 10;
}

# Extract the framework script and fill in the rest
open(SELF, "$0") || die("Failed to open running script");
while (<SELF>) {
	chomp($_);
	if ($_ ne "__END__") {
		next;
	}
	while (!eof(SELF)) {
		my $line = <SELF>;
		$line =~ s/__MONITOR_UPDATE_FREQUENCY__/$monitorInterval/;
		
		print $handle $line;
	}
}

# Contact
system("stap -DMAXSKIPPED=10485760 -DSTP_OVERLOAD_THRESHOLD=5000000000 $stapscript");
cleanup();
exit(0);
__END__
global total_allocs, total_frees, total_kmallocs, total_kfrees

probe kernel.function("kmem_cache_alloc_trace"),
	kernel.function("kmem_cache_alloc_node_trace")
{
	total_kmallocs++
}

probe kernel.function("kfree")
{
	if ($objp != NULL) {
		total_kfrees++
	}
}

probe kernel.function("kmem_cache_alloc"),
	kernel.function("kmem_cache_alloc_node")
{
	total_allocs++
}

probe kernel.function("kmem_cache_free")
{
	total_frees++
}

probe timer.s(__MONITOR_UPDATE_FREQUENCY__) {
	printf("time: %d\n", gettimeofday_s())

	printf("  total kmem_cache_allocs %12d %12d/sec\n", total_allocs,   total_allocs / __MONITOR_UPDATE_FREQUENCY__)
	printf("  total kmem_cache_frees  %12d %12d/sec\n", total_frees,    total_frees  / __MONITOR_UPDATE_FREQUENCY__)
	printf("  total kmallocs          %12d %12d/sec\n", total_kmallocs, total_kmallocs / __MONITOR_UPDATE_FREQUENCY__)
	printf("  total kfrees            %12d %12d/sec\n", total_kfrees,   total_kfrees  / __MONITOR_UPDATE_FREQUENCY__)
	printf("\n")

	total_allocs = 0
	total_frees = 0
	total_kmallocs = 0
	total_kfrees = 0
}
