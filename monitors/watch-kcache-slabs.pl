#!/usr/bin/perl
# This script is a combined perl and systemtap script to collect stats on
# slab activity.
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
system("stap -g -DMAXSKIPPED=10485760 -DSTP_OVERLOAD_THRESHOLD=5000000000 $stapscript");
cleanup();
exit(0);
__END__
global total_allocs, total_frees, total_kmallocs, total_kfrees

%{
#include <linux/slab_def.h>
%}

function ptr_to_cachep:long (addr:long) %{
	struct kmem_cache *cachep;
        struct page *page = virt_to_head_page((void *)STAP_ARG_addr);
	STAP_RETURN(kderef(sizeof(void *), page->slab_cache));
	CATCH_DEREF_FAULT ();
%}

probe kernel.function("kmem_cache_alloc_trace"),
	kernel.function("kmem_cache_alloc_node_trace")
{
	total_kmallocs[kernel_string(@cast($cachep, "struct kmem_cache")->name)]++
}

probe kernel.function("kfree")
{
	if ($objp > 16) {
		total_kfrees[kernel_string(@cast(ptr_to_cachep($objp), "kmem_cache")->name)]++
	}
}

probe kernel.function("kmem_cache_alloc"),
	kernel.function("kmem_cache_alloc_node")
{
	total_allocs[kernel_string(@cast($cachep, "kmem_cache")->name)]++
}

probe kernel.function("kmem_cache_free")
{
	total_frees[kernel_string(@cast($cachep, "kmem_cache")->name)]++
}

probe timer.s(__MONITOR_UPDATE_FREQUENCY__) {
	printf("time: %d\n", gettimeofday_s())

	foreach ([slabname] in total_kmallocs-) {
		printf("  total kmallocs          %-35s %7d %7d/sec\n", slabname, total_kmallocs[slabname],   total_kmallocs[slabname] / __MONITOR_UPDATE_FREQUENCY__)
	}
	foreach ([slabname] in total_allocs-) {
		printf("  total kmem_cache_allocs %-35s %7d %7d/sec\n", slabname, total_allocs[slabname],   total_allocs[slabname] / __MONITOR_UPDATE_FREQUENCY__)
	}
	foreach ([slabname] in total_kfrees-) {
		printf("  total kfrees            %-35s %7d %7d/sec\n", slabname, total_kfrees[slabname],   total_kfrees[slabname] / __MONITOR_UPDATE_FREQUENCY__)
	}
	foreach ([slabname] in total_frees-) {
		printf("  total kmem_cache_frees  %-35s %7d %7d/sec\n", slabname, total_frees[slabname],   total_frees[slabname] / __MONITOR_UPDATE_FREQUENCY__)
	}

	printf("\n")

	delete total_kmallocs
	delete total_allocs
	delete total_frees
	delete total_kfrees
}
