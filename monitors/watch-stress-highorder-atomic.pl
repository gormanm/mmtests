#!/usr/bin/perl
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

# Inherited from mmtests, yes there are alternatives
my $allocSize = $ENV{"MEMTOTAL_BYTES"};
if ($allocSize == 0) {
	$allocSize = 1024 * 1048576;
} else {
	$allocSize = $allocSize * 2 / 100;
}

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
		$line =~ s/__MONITOR_ALLOC_SIZE__/$allocSize/;
		
		print $handle $line;
	}
}

# Contact
system("stap -g -DMAXSKIPPED=10485760 -DSTP_OVERLOAD_THRESHOLD=5000000000 $stapscript");
cleanup();
exit(0);
__END__
%{
#include <linux/mmzone.h>
#include <linux/jiffies.h>
#include <linux/gfp.h>

int pause = 0;
#define ALLOC_ORDER 3
#define MAX_BURST (__MONITOR_ALLOC_SIZE__UL >> (PAGE_SHIFT + ALLOC_ORDER))
int burst_alloc = MAX_BURST;
struct page **max_alloc = NULL;
bool vmalloced = false;
%}

function atomic_alloc () %{
	int i, local_burst = burst_alloc;
	int success = 0, failure = 0;

	if (!max_alloc) {
		max_alloc = kmalloc(sizeof(struct page *) * MAX_BURST, GFP_ATOMIC | __GFP_NOWARN);
		if (!max_alloc) {
			_stp_printf("failed to alloc max_alloc array\n");
			return;
		}
	}

	if (pause) {
		pause--;
		return;
	}

	if (local_burst > MAX_BURST)
		local_burst = MAX_BURST;

	for (i = 0; i < local_burst; i++) {
		max_alloc[i] = alloc_pages(GFP_ATOMIC | __GFP_NOWARN, ALLOC_ORDER);
		if (!max_alloc[i])
			break;
	}

	success = i;
	failure = local_burst - success;

	for (i = 0; i < success; i++) {
		if (max_alloc[i])
			__free_pages(max_alloc[i], ALLOC_ORDER);
	}
	_stp_printf("atomic alloc burst %6d / %6d success %6d failure %6d\n",
			local_burst, MAX_BURST, success, failure);
	if (failure) {
		pause = 8;
	}
%}

function update_burst () %{
	burst_alloc = jiffies % MAX_BURST;
%}

function monitor_init() %{
	unsigned long size = sizeof(struct page *) * MAX_BURST;
	max_alloc = kmalloc(size, GFP_ATOMIC | __GFP_NOWARN);
	if (!max_alloc) {
		max_alloc = vmalloc(size);
		if (!max_alloc) {
			_stp_printf("Failed to allocate max_alloc at init");
		} else {
			_stp_printf("vmalloced max_alloc\n");
		}
	} else {
		_stp_printf("kmalloced max_alloc\n");
	}
%}

function monitor_end() %{
	if (vmalloced) {
		_stp_printf("vfree max_alloc\n");
		vfree(max_alloc);
	} else {
		_stp_printf("kfree max_alloc\n");
		kfree(max_alloc);
	}
	max_alloc = NULL;
%}

probe begin
{
	monitor_init()
}
probe end
{
	monitor_end()
}

probe timer.s(__MONITOR_UPDATE_FREQUENCY__)
{
	atomic_alloc()
	update_burst()
}
