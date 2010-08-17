#!/usr/bin/perl
# This is a tool that analyses the trace output related to page allocation,
# sums up the number of high-order allocations taking place and who the
# callers are
#
# Example usage: trace-pagealloc-highorder.pl -o output-report.txt
# options
# -o, --output	Where to store the report
#
# Copyright (c) IBM Corporation 2009
# Author: Mel Gorman <mel@csn.ul.ie>
use strict;
use Getopt::Long;

# Tracepoint events
use constant MM_PAGE_ALLOC		=> 1;
use constant EVENT_UNKNOWN		=> 7;

use constant HIGH_NORMAL_HIGHORDER_ALLOC	=> 10;
use constant HIGH_ATOMIC_HIGHORDER_ALLOC	=> 11;

my $opt_output;
my %stats;
my %unique_events;
my $last_updated = 0;

$stats{HIGH_NORMAL_HIGHORDER_ALLOC} = 0;
$stats{HIGH_ATOMIC_HIGHORDER_ALLOC} = 0;

# Catch sigint and exit on request
my $sigint_report = 0;
my $sigint_exit = 0;
my $sigint_pending = 0;
my $sigint_received = 0;
sub sigint_handler {
	my $current_time = time;
	if ($current_time - 2 > $sigint_received) {
		print "SIGINT received, report pending. Hit ctrl-c again to exit\n";
		$sigint_report = 1;
	} else {
		if (!$sigint_exit) {
			print "Second SIGINT received quickly, exiting\n";
		}
		$sigint_exit++;
	}

	if ($sigint_exit > 3) {
		print "Many SIGINTs received, exiting now without report\n";
		exit;
	}

	$sigint_received = $current_time;
	$sigint_pending = 1;
}
$SIG{INT} = "sigint_handler";

# Parse command line options
GetOptions(
	'output=s'    => \$opt_output,
);

# Defaults for dynamically discovered regex's
my $regex_pagealloc_default = 'page=([0-9a-f]*) pfn=([0-9]*) order=([-0-9]*) migratetype=([-0-9]*) gfp_flags=([A-Z_|]*)';

# Dyanically discovered regex
my $regex_pagealloc;

# Static regex used. Specified like this for readability and for use with /o
#                      (process_pid)     (cpus      )   ( time  )   (tpoint    ) (details)
my $regex_traceevent = '\s*([a-zA-Z0-9-]*)\s*(\[[0-9]*\])\s*([0-9.]*):\s*([a-zA-Z_]*):\s*(.*)';
my $regex_statname = '[-0-9]*\s\((.*)\).*';
my $regex_statppid = '[-0-9]*\s\(.*\)\s[A-Za-z]\s([0-9]*).*';

sub generate_traceevent_regex {
	my $event = shift;
	my $default = shift;
	my $regex;

	# Read the event format or use the default
	if (!open (FORMAT, "/sys/kernel/debug/tracing/events/$event/format")) {
		$regex = $default;
	} else {
		my $line;
		while (!eof(FORMAT)) {
			$line = <FORMAT>;
			if ($line =~ /^print fmt:\s"(.*)",.*/) {
				$regex = $1;
				$regex =~ s/%p/\([0-9a-f]*\)/g;
				$regex =~ s/%d/\([-0-9]*\)/g;
				$regex =~ s/%lu/\([0-9]*\)/g;
				$regex =~ s/%s/\([A-Z_|]*\)/g;
				$regex =~ s/\(REC->gfp_flags\).*/REC->gfp_flags/;
				$regex =~ s/\",.*//;
			}
		}
	}

	# Verify fields are in the right order
	my $tuple;
	foreach $tuple (split /\s/, $regex) {
		my ($key, $value) = split(/=/, $tuple);
		my $expected = shift;
		if ($key ne $expected) {
			print("WARNING: Format not as expected '$key' != '$expected'");
			$regex =~ s/$key=\((.*)\)/$key=$1/;
		}
	}

	if (defined shift) {
		die("Fewer fields than expected in format");
	}

	return $regex;
}
$regex_pagealloc = generate_traceevent_regex("kmem/mm_page_alloc",
			$regex_pagealloc_default,
			"page", "pfn",
			"order", "migratetype", "gfp_flags");

sub process_events {
	my $traceevent;
	my $process_pid = 0;
	my $cpus;
	my $timestamp;
	my $tracepoint;
	my $details;
	my $statline;
	my $nextline = 1;

	# Read each line of the event log
EVENT_PROCESS:
	while (($traceevent = <TRACING>) && !$sigint_exit) {
SKIP_LINEREAD:

		if ($traceevent eq "") {
			last EVENT_PROCSS;
		}

		if ($traceevent =~ /$regex_traceevent/o) {
			$process_pid = $1;
			$tracepoint = $4;
		} else {
			next;
		}

		# Perl Switch() sucks majorly
		if ($tracepoint eq "mm_page_alloc") {
			my ($page, $order, $gfp_flags, $type);
			my ($atomic);
			my $details = $5;

			if ($details !~ /$regex_pagealloc/o) {
				print "WARNING: Failed to parse mm_page_alloc as expected\n";
				print "$details\n";
				print "$regex_pagealloc\n";
				print "\n";
				next;
			}
			$page = $1;
			$order = $3;
			$gfp_flags = $5;

			# Only concerned with high-order allocs
			if ($order == 0) {
				next;
			}

			$stats{MM_PAGE_ALLOC}++;

			if ($gfp_flags =~ /ATOMIC/) {
				$stats{HIGH_ATOMIC_HIGHORDER_ALLOC}++;
				$type = "atomic";
			} else {
				$stats{HIGH_NORMAL_HIGHORDER_ALLOC}++;
				$type = "normal";
			}

			# Record the stack trace
			$traceevent = <TRACING>;
			if ($traceevent !~ /stack trace/) {
				goto SKIP_LINEREAD;
			}
			my $event = "order=$order $type gfp_flags=$gfp_flags\n";;
			while ($traceevent = <TRACING>) {
				if ($traceevent !~ /^ =>/) {
					$unique_events{$event}++;
					my $current = time;

					if ($current - $last_updated > 60) {
						$last_updated = $current;
						update_report();
					}
					goto SKIP_LINEREAD;
				}
				$event .= $traceevent;
			}
		} else {
			$stats{EVENT_UNKNOWN}++;
		}

		if ($sigint_pending) {
			last EVENT_PROCESS;
		}
	}
}

sub update_report() {
	my $event;
	open (REPORT, ">$opt_output") || die ("Failed to open $opt_output for writing");

	foreach $event (keys %unique_events) {
		print REPORT $unique_events{$event} . " instances $event\n";
	}
	print REPORT "High-order normal allocations: " . $stats{HIGH_NORMAL_HIGHORDER_ALLOC} . "\n";
	print REPORT "High-order atomic allocations: " . $stats{HIGH_ATOMIC_HIGHORDER_ALLOC} . "\n";

	close REPORT;
}

sub print_report() {
	print "\nReport\n";
	open (REPORT, $opt_output) || die ("Failed to open $opt_output for reading");
	while (<REPORT>) {
		print $_;
	}
	close REPORT;
}

# Process events or signals until neither is available
sub signal_loop() {
	my $sigint_processed;
	do {
		$sigint_processed = 0;
		process_events();

		# Handle pending signals if any
		if ($sigint_pending) {
			my $current_time = time;

			if ($sigint_exit) {
				print "Received exit signal\n";
				$sigint_pending = 0;
			}
			if ($sigint_report) {
				if ($current_time >= $sigint_received + 2) {
					update_report();
					print_report();
					$sigint_report = 0;
					$sigint_pending = 0;
					$sigint_processed = 1;
					$sigint_exit = 0;
				}
			}
		}
	} while ($sigint_pending || $sigint_processed);
}

sub set_traceoption($) {
	my $option = shift;

	open(TRACEOPT, ">/sys/kernel/debug/tracing/trace_options") || die("Failed to open trace_options");
	print TRACEOPT $option;
	close TRACEOPT;
}

sub enable_tracing($) {
	my $tracing = shift;

	open(TRACING, ">/sys/kernel/debug/tracing/events/$tracing/enable") || die("Failed to open tracing event $tracing");
	print TRACING "1";
	close TRACING;
}

sub disable_tracing($) {
	my $tracing = shift;

	open(TRACING, ">/sys/kernel/debug/tracing/events/$tracing/enable") || die("Failed to open tracing event $tracing");
	print TRACING "0";
	close TRACING;

}

set_traceoption("stacktrace");
set_traceoption("sym-offset");
set_traceoption("sym-addr");
enable_tracing("kmem/mm_page_alloc");
open(TRACING, "/sys/kernel/debug/tracing/trace_pipe") || die("Failed to open trace_pipe");
signal_loop();
close TRACING;
disable_tracing("kmem/mm_page_alloc");
update_report();
print_report();

