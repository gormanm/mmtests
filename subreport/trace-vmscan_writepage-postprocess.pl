#!/usr/bin/perl
use strict;
use Getopt::Long;

# Tracepoint events
use constant VMSCAN_WRITEPAGE		=> 1;
use constant EVENT_UNKNOWN			=> 3;

# High-level events extrapolated from tracepoints
use constant HIGH_VMSCAN_WRITEPAGE_ANON_SYNC		=> 11;
use constant HIGH_VMSCAN_WRITEPAGE_ANON_ASYNC		=> 12;
use constant HIGH_VMSCAN_WRITEPAGE_FILE_SYNC		=> 13;
use constant HIGH_VMSCAN_WRITEPAGE_FILE_ASYNC		=> 14;
use constant HIGH_VMSCAN_WRITEPAGE_MIXED_SYNC		=> 15;
use constant HIGH_VMSCAN_WRITEPAGE_MIXED_ASYNC		=> 16;

my %perprocesspid;
my %perprocess;
my %last_procmap;
my $opt_ignorepid;
my $opt_read_procstat;

my $total_direct_writepage_anon_sync = 0;
my $total_direct_writepage_anon_async = 0;
my $total_direct_writepage_file_sync = 0;
my $total_direct_writepage_file_async = 0;
my $total_direct_writepage_mixed_sync = 0;
my $total_direct_writepage_mixed_async = 0;
my $total_kswapd_writepage_anon_sync = 0;
my $total_kswapd_writepage_anon_async = 0;
my $total_kswapd_writepage_file_sync = 0;
my $total_kswapd_writepage_file_async = 0;
my $total_kswapd_writepage_mixed_sync = 0;
my $total_kswapd_writepage_mixed_async = 0;

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
my $regex_vmscan_writepage_default = 'page=([0-9a-f]*) pfn=([-0-9]*) flags=([0-9a-zA-Z|_])';

# Dyanically discovered regex
my $regex_vmscan_writepage;

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

$regex_vmscan_writepage = generate_traceevent_regex(
			"vmscan/mm_vmscan_writepage",
			$regex_vmscan_writepage_default,
			"page", "pfn", "flags");

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
		if ($tracepoint eq "mm_vmscan_writepage") {
			$timestamp = timestamp_to_ms($timestamp);

			$details = $5;
			if ($details !~ /$regex_vmscan_writepage/o) {
				print "WARNING: Failed to parse vmscan_writepage as expected\n";
				print "         $details\n";
				print "         $regex_vmscan_writepage/o\n";
				next;
			}
			my $page = $1;
			my $pfn = $2;
			my $flags = $3;

			$perprocesspid{$process_pid}->{VMSCAN_WRITEPAGE}++;

			# Could do tricks with indices here but could not be arsed.
			# This is mostly for offline usage so lets go with predictable
			if ($flags =~ /RECLAIM_WB_ANON/) {
				if ($flags =~ /RECLAIM_WB_ASYNC/) {
					$perprocesspid{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_ASYNC}++;
				} else {
					$perprocesspid{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_SYNC}++;
				}
			}
			if ($flags =~ /RECLAIM_WB_FILE/) {
				if ($flags =~ /RECLAIM_WB_ASYNC/) {
					$perprocesspid{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_ASYNC}++;
				} else {
					$perprocesspid{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_SYNC}++;
				}

			}
			if ($flags =~ /RECLAIM_WB_MIXED/) {
				if ($flags =~ /RECLAIM_WB_ASYNC/) {
					$perprocesspid{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_ASYNC}++;
				} else {
					$perprocesspid{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_SYNC}++;
				}
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
	printf("%-" . $max_strlen . "s %8s %10s   %8s %8s  %8s %8s\n", "Process", "Anon", "Anon",  "File", "File",  "Mixed", "Mixed");
	printf("%-" . $max_strlen . "s %8s %10s   %8s %8s  %8s %8s\n", "details", "Sync", "ASync", "Sync", "Async", "Sync",  "Async");
	foreach $process_pid (keys %stats) {
		next if ($opt_ignorepid && $process_pid =~ /kswapd[0-9]*/);
		next if (!$opt_ignorepid && $process_pid =~ /kswapd[0-9]*-.*/);
		next if (!$stats{$process_pid}->{VMSCAN_WRITEPAGE});

		$total_direct_writepage_anon_sync   += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_SYNC};
		$total_direct_writepage_anon_async  += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_ASYNC};
		$total_direct_writepage_file_sync   += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_SYNC};
		$total_direct_writepage_file_async  += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_ASYNC};
		$total_direct_writepage_mixed_sync  += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_SYNC};
		$total_direct_writepage_mixed_async += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_ASYNC};

		printf("%-" . $max_strlen . "s  %8d %10d   %8d %8d  %8d %ds",
			$process_pid,
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_SYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_ASYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_SYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_ASYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_SYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_ASYNC});

		print "\n";
	}

	# Print out kswapd activity
	printf("\n");
	printf("%-" . $max_strlen . "s %8s %10s   %8s %8s  %8s %8s\n", "Process", "Anon", "Anon",  "File", "File",  "Mixed", "Mixed");
	printf("%-" . $max_strlen . "s %8s %10s   %8s %8s  %8s %8s\n", "details", "Sync", "ASync", "Sync", "Async", "Sync",  "Async");
	foreach $process_pid (keys %stats) {
		next if ($opt_ignorepid && $process_pid !~ /kswapd[0-9]*/);
		next if (!$opt_ignorepid && $process_pid !~ /kswapd[0-9]*-.*/);
		next if (!$stats{$process_pid}->{VMSCAN_WRITEPAGE});
		$total_kswapd_writepage_anon_sync   += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_SYNC};
		$total_kswapd_writepage_anon_async  += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_ASYNC};
		$total_kswapd_writepage_file_sync   += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_SYNC};
		$total_kswapd_writepage_file_async  += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_ASYNC};
		$total_kswapd_writepage_mixed_sync  += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_SYNC};
		$total_kswapd_writepage_mixed_async += $stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_ASYNC};

		printf("%-" . $max_strlen . "s  %8d %10d   %8d %8d  %8d %ds",
			$process_pid,
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_SYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_ANON_ASYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_SYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_FILE_ASYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_SYNC},
			$stats{$process_pid}->{HIGH_VMSCAN_WRITEPAGE_MIXED_ASYNC});

		print "\n";
	}

	# Print out summaries
	print "\nSummary\n";
	print "Direct writes anon  sync:   $total_direct_writepage_anon_sync\n";
	print "Direct writes anon  async:  $total_direct_writepage_anon_async\n";
	print "Direct writes file  sync:   $total_direct_writepage_file_sync\n";
	print "Direct writes file  async:  $total_direct_writepage_file_async\n";
	print "Direct writes mixed sync:   $total_direct_writepage_mixed_sync\n";
	print "Direct writes mixed async:  $total_direct_writepage_mixed_async\n";
	print "KSwapd writes anon  sync:   $total_kswapd_writepage_anon_sync\n";
	print "KSwapd writes anon  async:  $total_kswapd_writepage_anon_async\n";
	print "KSwapd writes file  sync:   $total_kswapd_writepage_file_sync\n";
	print "KSwapd writes file  async:  $total_kswapd_writepage_file_async\n";
	print "KSwapd writes mixed sync:   $total_kswapd_writepage_mixed_sync\n";
	print "KSwapd writes mixed async:  $total_kswapd_writepage_mixed_async\n";
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
