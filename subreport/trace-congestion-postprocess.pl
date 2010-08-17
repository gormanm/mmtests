#!/usr/bin/perl
use strict;
use Getopt::Long;

# Tracepoint events
use constant WRITEBACK_CONGESTION_WAIT		=> 1;
use constant WRITEBACK_WAIT_IFF_CONGESTED	=> 2;
use constant EVENT_UNKNOWN			=> 3;

# High-level events extrapolated from tracepoints
use constant HIGH_WRITEBACK_CONGESTION_WAIT_TIME_WAITED		=> 11;
use constant HIGH_WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED	=> 12;
use constant HIGH_WRITEBACK_CONGESTION_WAIT_FULL		=> 13;
use constant HIGH_WRITEBACK_WAIT_IFF_CONGESTED_FULL		=> 14;

my %perprocesspid;
my %perprocess;
my %last_procmap;
my $opt_ignorepid;
my $opt_read_procstat;

my $total_direct_congested_waited = 0;
my $total_direct_condcongested_waited = 0;
my $total_direct_congested_time_waited = 0;
my $total_direct_condcongested_time_waited = 0;
my $total_direct_congested_full = 0;
my $total_direct_condcongested_full = 0;
my $total_kswapd_congested_waited = 0;
my $total_kswapd_condcongested_waited = 0;
my $total_kswapd_congested_time_waited = 0;
my $total_kswapd_condcongested_time_waited = 0;
my $total_kswapd_congested_full = 0;
my $total_kswapd_condcongested_full = 0;

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
	'ignore-pid'	 =>	\$opt_ignorepid,
	'read-procstat'	 =>	\$opt_read_procstat,
);

# Defaults for dynamically discovered regex's
my $regex_writeback_congestion_wait_default = 'usec_timeout=([0-9]*) usec_delayed=([0-9]*)';
my $regex_writeback_wait_iff_congested_default = 'usec_timeout=([0-9]*) usec_delayed=([0-9]*)';

# Dyanically discovered regex
my $regex_writeback_congestion_wait;
my $regex_writeback_wait_iff_congested;

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
		print("WARNING: Event $event format string not found\n");
		return $default;
	} else {
		my $line;
		while (!eof(FORMAT)) {
			$line = <FORMAT>;
			$line =~ s/, REC->.*//;
			if ($line =~ /^print fmt:\s"(.*)".*/) {
				$regex = $1;
				$regex =~ s/%s/\([0-9a-zA-Z|_]*\)/g;
				$regex =~ s/%p/\([0-9a-f]*\)/g;
				$regex =~ s/%d/\([-0-9]*\)/g;
				$regex =~ s/%u/\([0-9]*\)/g;
				$regex =~ s/%ld/\([-0-9]*\)/g;
				$regex =~ s/%lu/\([0-9]*\)/g;
			}
		}
	}

	# Can't handle the print_flags stuff but in the context of this
	# script, it really doesn't matter
	$regex =~ s/\(REC.*\) \? __print_flags.*//;

	# Verify fields are in the right order
	my $tuple;
	foreach $tuple (split /\s/, $regex) {
		my ($key, $value) = split(/=/, $tuple);
		my $expected = shift;
		if ($key ne $expected) {
			print("WARNING: Format not as expected for event $event '$key' != '$expected'\n");
			$regex =~ s/$key=\((.*)\)/$key=$1/;
		}
	}

	if (defined shift) {
		die("Fewer fields than expected in format");
	}

	return $regex;
}

$regex_writeback_congestion_wait = generate_traceevent_regex(
			"writeback/writeback_congestion_wait",
			$regex_writeback_congestion_wait_default,
			"usec_timeout", "usec_delayed");
$regex_writeback_wait_iff_congested = generate_traceevent_regex(
			"writeback/writeback_wait_iff_congested",
			$regex_writeback_wait_iff_congested_default,
			"usec_timeout", "usec_delayed");

sub read_statline($) {
	my $pid = $_[0];
	my $statline;

	if (open(STAT, "/proc/$pid/stat")) {
		$statline = <STAT>;
		close(STAT);
	}

	if ($statline eq '') {
		$statline = "-1 (UNKNOWN_PROCESS_NAME) R 0";
	}

	return $statline;
}

sub guess_process_pid($$) {
	my $pid = $_[0];
	my $statline = $_[1];

	if ($pid == 0) {
		return "swapper-0";
	}

	if ($statline !~ /$regex_statname/o) {
		die("Failed to math stat line for process name :: $statline");
	}
	return "$1-$pid";
}

# Convert sec.usec timestamp format
sub timestamp_to_ms($) {
	my $timestamp = $_[0];

	my ($sec, $usec) = split (/\./, $timestamp);
	return ($sec * 1000) + ($usec / 1000);
}

sub process_events {
	my $traceevent;
	my $process_pid;
	my $cpus;
	my $timestamp;
	my $tracepoint;
	my $details;
	my $statline;

	# Read each line of the event log
EVENT_PROCESS:
	while ($traceevent = <STDIN>) {
		if ($traceevent =~ /$regex_traceevent/o) {
			$process_pid = $1;
			$timestamp = $3;
			$tracepoint = $4;

			$process_pid =~ /(.*)-([0-9]*)$/;
			my $process = $1;
			my $pid = $2;

			if ($process eq "") {
				$process = $last_procmap{$pid};
				$process_pid = "$process-$pid";
			}
			$last_procmap{$pid} = $process;

			if ($opt_read_procstat) {
				$statline = read_statline($pid);
				if ($opt_read_procstat && $process eq '') {
					$process_pid = guess_process_pid($pid, $statline);
				}
			}
		} else {
			next;
		}

		# Perl Switch() sucks majorly
		if ($tracepoint eq "writeback_congestion_wait") {
			$timestamp = timestamp_to_ms($timestamp);

			$details = $5;
			if ($details !~ /$regex_writeback_congestion_wait/o) {
				print "WARNING: Failed to parse writeback_congestion_wait as expected\n";
				print "         $details\n";
				print "         $regex_writeback_congestion_wait/o\n";
				next;
			}
			my $usec_timeout = $1;
			my $usec_delayed = $2;

			$perprocesspid{$process_pid}->{WRITEBACK_CONGESTION_WAIT}++;
			$perprocesspid{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_TIME_WAITED} += $usec_delayed;
			if ($usec_timeout <= $usec_delayed) {
				$perprocesspid{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_FULL}++;
			}
		} elsif ($tracepoint eq "writeback_wait_iff_congested") {
			$timestamp = timestamp_to_ms($timestamp);

			$details = $5;
			if ($details !~ /$regex_writeback_wait_iff_congested/o) {
				print "WARNING: Failed to parse writeback_wait_iff_congested as expected\n";
				print "         $details\n";
				print "         $regex_writeback_wait_iff_congested/o\n";
				next;
			}
			my $usec_timeout = $1;
			my $usec_delayed = $2;


			$perprocesspid{$process_pid}->{WRITEBACK_WAIT_IFF_CONGESTED}++;
			$perprocesspid{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED} += $usec_delayed;
			if ($usec_timeout <= $usec_delayed) {
				$perprocesspid{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_FULL}++;
			}
		} else {
			$perprocesspid{$process_pid}->{EVENT_UNKNOWN}++;
		}

		if ($sigint_pending) {
			last EVENT_PROCESS;
		}
	}
}

sub dump_stats {
	my $hashref = shift;
	my %stats = %$hashref;

	# Dump per-process stats
	my $process_pid;
	my $max_strlen = 0;

	# Get the maximum process name
	foreach $process_pid (keys %perprocesspid) {
		my $len = length($process_pid);
		if ($len > $max_strlen) {
			$max_strlen = $len;
		}
	}
	$max_strlen += 2;

	# Print out process activity
	printf("\n");
	printf("%-" . $max_strlen . "s %8s %10s   %8s %8s  %8s %8s\n", "Process", "Congestion", "CongestTime", "Conditional", "ConditionalTime", "Congestion", "Conditional");
	printf("%-" . $max_strlen . "s %8s %10s   %8s %8s  %8s %8s\n", "details", "Waited",     "Waited",      "Waited",      "Waited",          "TimedOut",   "TimedOut");
	foreach $process_pid (keys %stats) {
		next if ($opt_ignorepid && $process_pid =~ /kswapd[0-9]*/);
		next if (!$opt_ignorepid && $process_pid =~ /kswapd[0-9]*-.*/);
		next if (!$stats{$process_pid}->{WRITEBACK_CONGESTION_WAIT} && !$stats{$process_pid}->{WRITEBACK_WAIT_IFF_CONGESTED});

		$total_direct_congested_waited += $stats{$process_pid}->{WRITEBACK_CONGESTION_WAIT};
		$total_direct_congested_time_waited += $stats{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_TIME_WAITED};
		$total_direct_condcongested_waited += $stats{$process_pid}->{WRITEBACK_WAIT_IFF_CONGESTED};
		$total_direct_condcongested_time_waited += $stats{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED};
		$total_direct_congested_full += $stats{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_FULL};
		$total_direct_condcongested_full += $stats{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_FULL};

		printf("%-" . $max_strlen . "s  %8d %10d   %8d %8d  %8d %ds",
			$process_pid,
			$stats{$process_pid}->{WRITEBACK_CONGESTION_WAIT},
			$stats{$process_pid}->{WRITEBACK_WAIT_IFF_CONGESTED},
			$stats{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_TIME_WAITED} / 1000,
			$stats{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED} / 1000,
			$stats{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_FULL},
			$stats{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_FULL});

		print "\n";
	}

	# Print out kswapd activity
	printf("\n");
	printf("%-" . $max_strlen . "s %8s %10s   %8s %8s  %8s %8s\n", "Process", "Congestion", "CongestTime", "Conditional", "ConditionalTime", "Congestion", "Conditional");
	printf("%-" . $max_strlen . "s %8s %10s   %8s %8s  %8s %8s\n", "details", "Waited",     "Waited",      "Waited",      "Waited",          "TimedOut",   "TimedOut");
	foreach $process_pid (keys %stats) {
		next if ($opt_ignorepid && $process_pid !~ /kswapd[0-9]*/);
		next if (!$opt_ignorepid && $process_pid !~ /kswapd[0-9]*-.*/);
		next if (!$stats{$process_pid}->{WRITEBACK_CONGESTION_WAIT} && !$stats{$process_pid}->{WRITEBACK_WAIT_IFF_CONGESTED});

		$total_kswapd_congested_waited += $stats{$process_pid}->{WRITEBACK_CONGESTION_WAIT};
		$total_kswapd_congested_time_waited += $stats{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_TIME_WAITED};
		$total_kswapd_condcongested_waited += $stats{$process_pid}->{WRITEBACK_WAIT_IFF_CONGESTED};
		$total_kswapd_condcongested_time_waited += $stats{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED};
		$total_kswapd_congested_full += $stats{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_FULL};
		$total_kswapd_condcongested_full += $stats{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_FULL};


		printf("%-" . $max_strlen . "s  %8d %10d   %8d %8d  %8d %ds",
			$process_pid,
			$stats{$process_pid}->{WRITEBACK_CONGESTION_WAIT},
			$stats{$process_pid}->{WRITEBACK_WAIT_IFF_CONGESTED},
			$stats{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_TIME_WAITED} / 1000,
			$stats{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED} / 1000,
			$stats{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_FULL},
			$stats{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_FULL});

		print "\n";
	}

	# Print out summaries
	$total_direct_congested_time_waited /= 1000;
	$total_direct_condcongested_time_waited /= 1000;
	$total_kswapd_congested_time_waited /= 1000;
	$total_kswapd_condcongested_time_waited /= 1000;
	print "\nSummary\n";
	print "Direct number congest     waited:   $total_direct_congested_waited\n";
	print "Direct time   congest     waited:   $total_direct_congested_time_waited ms\n";
	print "Direct full   congest     waited:   $total_direct_congested_full\n";
	print "Direct number conditional waited:   $total_direct_condcongested_waited\n";
	print "Direct time   conditional waited:   $total_direct_condcongested_time_waited ms\n";
	print "Direct full   conditional waited:   $total_direct_condcongested_full\n";
	print "KSwapd number congest     waited:   $total_kswapd_congested_waited\n";
	print "KSwapd time   congest     waited:   $total_kswapd_congested_time_waited ms\n";
	print "KSwapd full   congest     waited:   $total_kswapd_congested_full\n";
	print "KSwapd number conditional waited:   $total_kswapd_condcongested_waited\n";
	print "KSwapd time   conditional waited:   $total_kswapd_condcongested_time_waited ms\n";
	print "KSwapd full   conditional waited:   $total_kswapd_condcongested_full\n";

}

sub aggregate_perprocesspid() {
	my $process_pid;
	my $process;
	undef %perprocess;

	foreach $process_pid (keys %perprocesspid) {
		$process = $process_pid;
		$process =~ s/-([0-9])*$//;
		if ($process eq '') {
			$process = "NO_PROCESS_NAME";
		}

		$perprocess{$process}->{WRITEBACK_CONGESTION_WAIT} += $perprocesspid{$process_pid}->{WRITEBACK_CONGESTION_WAIT};
		$perprocess{$process}->{WRITEBACK_WAIT_IFF_CONGESTED} += $perprocesspid{$process_pid}->{WRITEBACK_WAIT_IFF_CONGESTED};
		$perprocess{$process}->{HIGH_WRITEBACK_CONGESTION_WAIT_TIME_WAITED} += $perprocesspid{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_TIME_WAITED};
		$perprocess{$process}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED} += $perprocesspid{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED};
		$perprocess{$process}->{HIGH_WRITEBACK_CONGESTION_WAIT_FULL} += $perprocesspid{$process_pid}->{HIGH_WRITEBACK_CONGESTION_WAIT_FULL};
		$perprocess{$process}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_FULL} += $perprocesspid{$process_pid}->{HIGH_WRITEBACK_WAIT_IFF_CONGESTED_FULL};
	}
}

sub report() {
	if (!$opt_ignorepid) {
		dump_stats(\%perprocesspid);
	} else {
		aggregate_perprocesspid();
		dump_stats(\%perprocess);
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
					report();
					$sigint_report = 0;
					$sigint_pending = 0;
					$sigint_processed = 1;
				}
			}
		}
	} while ($sigint_pending || $sigint_processed);
}

signal_loop();
report();
