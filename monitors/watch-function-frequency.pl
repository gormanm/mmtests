#!/usr/bin/perl
# This is a dirty hack to count a list of functions and unique stack
# traces
# Copyright Mel Gorman 2013
use strict;
use File::Temp qw/mkstemp/;

my @func_list;
if ($#ARGV != -1) {
	print "ARGV\n";
	@func_list = @ARGV;
} else {
	print "ENV\n";
	my $envList = $ENV{MONITOR_FUNCTION_FREQUENCY};
	@func_list = split(/\s+/, $envList);
}

die("Specify list of functions to trace") if ($#func_list == -1);

# Handle cleanup of temp files
my $stappid;
my $exiting = 0;
my ($handle, $stapscript) = mkstemp("/tmp/stapdXXXXX");
sub cleanup {
	if (defined($stappid)) {
		kill INT => $stappid;
	}
	unlink($stapscript);
}
sub sigint_handler {
	if (defined($stappid)) {
		kill INT => $stappid;
	}
	$exiting = 1;
}
$SIG{INT} = "sigint_handler";
$SIG{TERM} = "sigint_handler";

# Create the stap script
my ($handle, $stapscript) = mkstemp("/tmp/stapdXXXXX");
for my $funcName (@func_list) {
	print $handle <<EOF
probe kernel.function("$funcName") {
	p = pid()
	printf("ping %d %s\\n", p, execname())
	print_syms(backtrace())
}
EOF
}

# Fire up the stap script
$stappid = open(STAP, "stap -v -d ext4 -d jbd2 -DSTP_NO_OVERLOAD $stapscript|");
if (!defined($stappid)) {
	die("Failed to execute stap script");
}

# Read the raw output of the script
my $line;
my $nr_events =0;
my %unique_event_counts;
my ($process, $function, $event);
my ($stall_details, $trace, $first_trace, $reading_trace);
while (!$exiting && !eof(STAP)) {
	my $line = <STAP>;
	# Watch for the beginning of a new stack trace
	if ($line =~ /^ping/) {

		if ($trace ne "") {
			# Record the last event
			$unique_event_counts{$trace}++;
		}

		# Start the next event
		$reading_trace = 0;
		$nr_events++;

		$first_trace = "";
		$trace = "";
	}

	# If we have reached a trace, blindly read it
	if ($reading_trace) {
		$trace .= $line;
		if ($first_trace eq "") {
			$first_trace = $line;
		}
		next;
	}

	if ($line =~ /^ 0x/) {
		$reading_trace = 1;
		next;
	}
}
close(STAP);

# Dump the unique traces
foreach my $trace (sort {$unique_event_counts{$b} <=> $unique_event_counts{$a}} keys %unique_event_counts) {
	printf "Event count:		%8d\n", $unique_event_counts{$trace};
	print "$trace\n";
}

cleanup();
exit(0);
