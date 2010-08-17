#!/usr/bin/perl
# watch-highorder-latency - Print out allocation latencies
# This is a very simple script that just dumps out how long an allocation took.
# It's incompatible to run with any other tracing as assumptions are being
# made about the output

use strict;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

my $ftrace_prefix="/sys/kernel/debug/tracing";
my $exiting = 0;
my $highorder_only = 1;

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
write_value("$ftrace_prefix/set_ftrace_filter", "__alloc_pages_nodemask");
write_value("$ftrace_prefix/current_tracer", "function_graph");
write_value("$ftrace_prefix/events/kmem/mm_page_alloc/enable", "1");

open(FTRACE_PIPE, "$ftrace_prefix/trace_pipe") or die("Failed to open trace_pipe");
my $line;
my (@elements, $latency, $order);
my ($sec, $msec);
my $status;

# Yes, this check means that a line of input from the pipe is required before
# an update to exiting is noticed. In this case, it's expected there will be
# a page allocation soon
while (!eof(FTRACE_PIPE) && !$exiting) {
	$line = <FTRACE_PIPE>;
	if ($line =~ /.*mm_page_alloc:.*/) {
		@elements = split(/\s+/, $line);

		if ($elements[6] eq "(null)") {
			$status = "failure";
			$order = $elements[8];
		} else {
			$status = "success";
			$order = $elements[7];
		}
		$order = substr $order, 6;
		if ($highorder_only && $order == 0) {
			next;
		}
		
		$line = <FTRACE_PIPE>;
		while ($line !~ /\|  }$/) {
			$line = <FTRACE_PIPE>;
		}
		@elements = split(/\s+/, $line);
		$latency = $elements[2];
		if ( $latency !~ /^[0-9]/) {
			$latency = $elements[3];
		}
		if ( $latency !~ /^[0-9]/) {
			$latency = "BROKEN: $line";
		}
		($sec, $msec) = gettimeofday;

		print "$sec.$msec $order $latency $status\n";
	}
}

close(FTRACE_PIPE);
