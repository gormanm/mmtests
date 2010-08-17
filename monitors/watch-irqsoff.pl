#!/usr/bin/perl
# watch-irqsoff - Monitor what the largest IRQ latency source was over time
# This script enables the irqs-off function tracer and periodically reads
# and resets the tracer.
#
# This tracer script cannot be run in conjunction with other tracers
#
# Copyright Mel Gorman 2011
use strict;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

my $ftrace_prefix="/sys/kernel/debug/tracing";
my $exiting = 0;
my $highorder_only = 1;
my $update_frequency;

sub write_value {
	my ($file, $value) = @_;

	open (SYSFS, ">$file") or die("Failed to open $file for writing");
	print SYSFS $value;
	close SYSFS
}

sub sigint_handler {
	$exiting = 1;
}
$SIG{INT} = "sigint_handler";

# Configure ftrace to capture allocation latencies
write_value("$ftrace_prefix/current_tracer",      "irqsoff");
write_value("$ftrace_prefix/tracing_max_latency", "0");
write_value("$ftrace_prefix/tracing_enabled",     "1");

# How often should the tracer be read and reset
$update_frequency = $ENV{"MONITOR_UPDATE_FREQUENCY"};
if ($update_frequency eq "") {
	$update_frequency = 10;
}

while (!$exiting) {
	print "time: " . time . "\n";
	open(FTRACE, "$ftrace_prefix/trace") or die("Failed to open trace");
	while (!eof(FTRACE)) {
		print <FTRACE>;
	}
	close(FTRACE);
	write_value("$ftrace_prefix/tracing_max_latency", "0");
	sleep($update_frequency);
}

close(FTRACE_PIPE);
