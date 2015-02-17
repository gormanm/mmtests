#!/usr/bin/perl
# This script is a combined perl and systemtap script to collect stats on
# syscall activity. The intention is to quickly build a picture of how the
# workload is interfacting with the system from a high-level point of view
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

my $monitorThreshold = $ENV{"MONITOR_SYSCALL_FREQUENCY"};
if ($monitorThreshold == 0) {
	$monitorThreshold = 50;
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
		$line =~ s/__MONITOR_SYSCALL_FREQUENCY__/$monitorThreshold/;
		
		print $handle $line;
	}
}

# Contact
system("stap $stapscript");
cleanup();
exit(0);
__END__
global sysentery, timebytid
global tidTopid, pidToexec

probe syscall.* {
	sysentery[name, tid()] = gettimeofday_ns()
}

probe syscall.*.return {
	tid = tid();
	pid = pid();

	if (!([name, tid] in sysentery))
		next
	if (pid == 0)
		next

	pid = pid();
	timebytid[name, tid] <<< gettimeofday_ns() - sysentery[name, tid]
	tidTopid[tid] = pid
	pidToexec[pid] = execname()

	delete sysentery[name, tid]
}

probe timer.s(__MONITOR_UPDATE_FREQUENCY__) {
	printf("time: %d\n", gettimeofday_s())
	foreach ([call, tid-] in timebytid) {
		pid = tidTopid[tid]
		if (pid == 0)
			continue

		count = @count(timebytid[call, tid])
		if (count < __MONITOR_SYSCALL_FREQUENCY__)
			continue

		printf("%10d %10d %22s %22s %12d %12d\n",
			tid, pid, pidToexec[pid],
			call,
			@count(timebytid[call, tid]),
			@sum(timebytid[call, tid]))
	}
	delete timebytid
	delete tidTopid
	delete pidToexec
	printf("\n")
}
