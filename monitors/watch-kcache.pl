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

my $verbose = $ENV{"MONITOR_KCACHE_VERBOSE"};
if ($verbose eq "" || $verbose eq "yes") {
	$verbose = 1;
} else {
	$verbose = 0;
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
		$line =~ s/__MONITOR_KCACHE_VERBOSE__/$verbose/;
		
		print $handle $line;
	}
}

# Contact
system("stap -DMAXMAPENTRIES=524288 -DMAXACTION=5000000 -DMAXSKIPPED=10485760 -DSTP_OVERLOAD_THRESHOLD=5000000000 $stapscript");
cleanup();
exit(0);
__END__
global tidTopid, pidToexec
global kmallocs, kfrees
global allocs, frees

probe vm.kmalloc, vm.kmalloc_node
{
	tid = tid();
	pid = pid();

	if (pid == 0)
		next

	tidTopid[tid] = pid;
	pidToexec[pid] = execname()

	kmallocs[tid, caller_function, call_site]++
}

probe vm.kfree
{
	tid = tid();
	pid = pid();

	if (pid == 0)
		next

	tidTopid[tid] = pid;
	pidToexec[pid] = execname()

	kfrees[tid, caller_function, call_site]++
}

probe vm.kmem_cache_alloc, vm.kmem_cache_alloc_node
{
	tid = tid();
	pid = pid();

	if (pid == 0)
		next

	tidTopid[tid] = pid;
	pidToexec[pid] = execname()

	allocs[tid, caller_function, call_site]++
}

probe vm.kmem_cache_free
{
	tid = tid();
	pid = pid();

	if (pid == 0)
		next

	tidTopid[tid] = pid;
	pidToexec[pid] = execname()
	frees[tid, caller_function, call_site]++
}

probe timer.s(__MONITOR_UPDATE_FREQUENCY__) {
	printf("time: %d\n", gettimeofday_s())
	total_allocs = 1
	total_frees = 1
	total_kmallocs = 0
	total_kfrees = 0
	foreach ([tid, caller_function, call_site] in kmallocs-) {
		pid = tidTopid[tid]
		if (pid == 0)
			continue

		count = kmallocs[tid, caller_function, call_site]
		if (__MONITOR_KCACHE_VERBOSE__) {
			printf("kmalloc          %10d %10d %22s %22s %p %12d\n",
				tid, pid, pidToexec[pid],
				caller_function, call_site, count)
		}
		total_kmallocs += count
	}
	foreach ([tid, caller_function, call_site] in allocs-) {
		pid = tidTopid[tid]
		if (pid == 0)
			continue

		count = allocs[tid, caller_function, call_site]
		if (__MONITOR_KCACHE_VERBOSE__) {
			printf("kmem_cache_alloc %10d %10d %22s %22s %p %12d\n",
				tid, pid, pidToexec[pid],
				caller_function, call_site, count)
		}
		total_allocs += count
	}
	foreach ([tid, caller_function, call_site] in kfrees-) {
		pid = tidTopid[tid]
		if (pid == 0)
			continue

		count = kfrees[tid, caller_function, call_site]
		if (__MONITOR_KCACHE_VERBOSE__) {
			printf("kfrees           %10d %10d %22s %22s %p %12d\n",
				tid, pid, pidToexec[pid],
				caller_function, call_site, count)
		}
		total_kfrees += count
	}

	foreach ([tid, caller_function, call_site] in frees-) {
		pid = tidTopid[tid]
		if (pid == 0)
			continue

		count = frees[tid, caller_function, call_site]
		if (__MONITOR_KCACHE_VERBOSE__) {
			printf("kmem_cache_free  %10d %10d %22s %22s %p %12d\n",
				tid, pid, pidToexec[pid],
				caller_function, call_site, count)
		}
		total_frees += count
	}

	printf("  total kmem_cache_allocs %12d %12d/sec\n", total_allocs,   total_allocs / __MONITOR_UPDATE_FREQUENCY__)
	printf("  total kmem_cache_frees  %12d %12d/sec\n", total_frees,    total_frees  / __MONITOR_UPDATE_FREQUENCY__)
	printf("  total kmallocs          %12d %12d/sec\n", total_kmallocs, total_kmallocs / __MONITOR_UPDATE_FREQUENCY__)
	printf("  total kfrees            %12d %12d/sec\n", total_kfrees,   total_kfrees  / __MONITOR_UPDATE_FREQUENCY__)

	delete allocs
	delete frees
	delete kmallocs
	delete kfrees
	delete tidTopid
	delete pidToexec
	printf("\n")
}
