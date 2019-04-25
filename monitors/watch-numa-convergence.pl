#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/../bin/lib/";
use MMTests::MonitorNumaconvergence;

my $exiting = 0;
sub sigint_handler {
	$exiting = 1;
}
$SIG{INT} = "sigint_handler";

$update_frequency = $ENV{"MONITOR_UPDATE_FREQUENCY"};
if ($update_frequency eq "") {
	$update_frequency = 10;
}

my $monitorModule = MMTests::MonitorNumaconvergence->new();
$monitorModule->initialise();

while (!$exiting) {
	open FILE, "/proc/vmstat" or die "Couldn't open /proc/vmstat: $!"; 
	$vmstat = join("", <FILE>); 
	close FILE;
	$monitorModule->parseVMStat($vmstat);
	printf "%d %8.6f\n", time, $monitorModule->currentConvergence();
	sleep($update_frequency);
}
