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
system("stap -g $stapscript");
cleanup();
exit(0);
__END__
%{
#include <linux/mmzone.h>
#include <linux/jiffies.h>
#include <linux/gfp.h>

int pause = 0;
#define ALLOC_ORDER 3
#define MAX_BURST (1073741824UL >> (PAGE_SHIFT + ALLOC_ORDER))
int burst_alloc = MAX_BURST;
%}

function atomic_alloc () %{
	struct page **max_alloc;
	int i, local_burst = burst_alloc;
	int success = 0, failure = 0;

	max_alloc = kmalloc(sizeof(struct page *) * MAX_BURST, GFP_KERNEL);
	if (!max_alloc) {
		_stp_printf("failed to alloc max_alloc array\n");
		return;
	}

	if (pause) {
		pause--;
		kfree(max_alloc);
		return;
	}

	if (local_burst > MAX_BURST)
		local_burst = MAX_BURST;

	for (i = 0; i < local_burst; i++) {
		max_alloc[i] = alloc_pages(GFP_ATOMIC, ALLOC_ORDER);
		if (!max_alloc[i])
			break;
	}

	success = i;
	failure = local_burst - success;

	for (i = 0; i < success; i++) {
		if (max_alloc[i])
			__free_pages(max_alloc[i], ALLOC_ORDER);
	}
	_stp_printf("atomic alloc burst %6d success %6d failure %6d\n",
			local_burst, success, failure);
	if (failure) {
		pause = 8;
	}

	kfree(max_alloc);
%}

function update_burst () %{
	burst_alloc = jiffies % MAX_BURST;
%}

probe timer.s(__MONITOR_UPDATE_FREQUENCY__)
{
	atomic_alloc()
	update_burst()
}
