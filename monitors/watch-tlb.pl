#!/usr/bin/perl
# This is a tool that analyses the trace output related to TLB activity
#
# Copyright (c) SUSE Labs 2015
# Author: Mel Gorman <mel@csn.ul.ie>
use strict;
use Getopt::Long;

# Tracepoint events
use constant TLB_FLUSH		=> 1;
use constant EVENT_UNKNOWN		=> 7;

my $opt_output;
my $opt_output_temporary = 0;
my %stats;
my %unique_events;

# Catch sigint and exit on request
my $sigint_report = 0;
my $sigint_exit = 0;
my $sigint_pending = 0;
my $sigint_received = 0;
sub sigint_handler {
	my $current_time = time;
	print "SIGINT received, report pending.\n";
	$sigint_report = 1;
	$sigint_exit++;

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

if ($opt_output eq "") {
	$opt_output = "/tmp/mmtests.tlb.$$";
	$opt_output_temporary = 1;
}

# Defaults for dynamically discovered regex's
my $regex_tlb_flush_default = 'pages=([0-9-]*) reason=([A-Za-z_\s]*) \(.*\)';

# Dyanically discovered regex
my $regex_tlb_flush;

# Static regex used. Specified like this for readability and for use with /o
#                      (process_pid)     (cpus      )   ( time  )   (tpoint    ) (details)
my $regex_traceevent = '\s*([a-zA-Z0-9-]*)\s*(\[[0-9]*\])\s*[a-z.]*\s*([0-9.]*):\s*([a-zA-Z_]*):\s*(.*)';
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
				$regex =~ s/%ld/\([0-9-]*\)/g;
				$regex =~ s/%s/\([a-zA-Z_|\\s]*\)/g;
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
$regex_tlb_flush = generate_traceevent_regex("tlb/tlb_flush",
			$regex_tlb_flush_default,
			"pages", "reason");

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
		if ($tracepoint eq "tlb_flush") {
			my ($pages, $reason);
			my $details = $5;

			if ($details !~ /$regex_tlb_flush/o) {
				print "WARNING: Failed to parse tlb_flush as expected\n";
				print "$details\n";
				print "$regex_tlb_flush\n";
				print "\n";
				next;
			}
			$pages = $1;
			$reason = $2;

			$stats{TLB_FLUSH}++;

			# Record the stack trace
			$traceevent = <TRACING>;
			if ($traceevent !~ /stack trace/) {
				goto SKIP_LINEREAD;
			}

			if ($pages == 1) {
				$pages = "single";
			} elsif ($pages < 33) {
				$pages = "small";
			} elsif ($pages > 10000000000) {
				$pages = "many";
			} elsif ($pages == -1) {
				$pages = "ALL";
			} else {
				$pages = int ($pages / 33);
			}

			my $direction;
			if ($reason =~ /flush on t/) {
				$direction = "TASK SWITCH";
			} elsif ($reason =~ /remote shootdown/) {
				$direction = "RECEIVED IPI";
			} elsif ($reason =~ /local shootdown/) {
				$direction = "LOCAL CURRENT";
			} elsif ($reason =~ /local mm/) {
				$direction = "LOCAL FLUSH RANGE";
			} elsif ($reason =~ /remote ipi/) {
				$direction = "SENDING IPI";
			} else {
				$direction = "UNKNOWN";
			}

			my $event = "flush_ceilings=$pages reason=$reason $direction\n";;
			while ($traceevent = <TRACING>) {
				if ($traceevent !~ /^ =>/) {
					$unique_events{$event}++;
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

	foreach $event (sort {$unique_events{$b} <=> $unique_events{$a}} keys %unique_events) {
		print REPORT $unique_events{$event} . " instances $event\n";
	}

	close REPORT;
}

sub print_report() {
	print "\nReport\n";
	open (REPORT, $opt_output) || die ("Failed to open $opt_output for reading");
	while (<REPORT>) {
		print $_;
	}
	close REPORT;
	if ($opt_output_temporary) {
		unlink("/tmp/mmtests.tlb.$$");
	}
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
enable_tracing("tlb/tlb_flush");
open(TRACING, "/sys/kernel/debug/tracing/trace_pipe") || die("Failed to open trace_pipe");
signal_loop();
close TRACING;
disable_tracing("tlb/tlb_flush");
update_report();
print_report();
