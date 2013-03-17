#!/usr/bin/perl
# This script is a combined perl and systemtap script to collect information
# on a system stalling in writeback. Ordinarily, one would expect that all
# information be collected in a STAP script. Unfortunately, in practice the
# stack unwinder in systemtap may not work with a current kernel version,
# have trouble collecting all the data necessary or some other oddities.
# Hence this hack. A systemtap script is run and as it records interesting
# events, the remaining information is collected from the script. This means
# that the data is *never* exact but can be better than nothing and easier
# than a fully manual check
#
# Copyright Mel Gorman <mgorman@suse.de> 2011

use File::Temp qw/mkstemp/;
use File::Find;
use FindBin qw($Bin);
use Getopt::Long;
use strict;

my @trace_functions = (
	# "get_request_wait" is now special cased unfortunately
	"wait_for_completion",
	"wait_on_page_bit",
	"wait_on_page_bit_killable",
	"try_to_free_pages",
	"shrink_zone");

my @completion_functions=(
	"handle_mm_fault",
	"sys_select",
	"__wake_up",
	"wake_up_bit",
	"__alloc_pages_nodemask",
	"balance_pgdat",
	"kmem_cache_alloc");

my @trace_conditional = (
	"sync_page",
	"sync_buffer",
	"sleep_on_buffer",
	"try_to_compact_pages",
	"balance_dirty_pages_ratelimited_nr",
	"balance_dirty_pages");

# Information on each stall is gathered and stored in a hash table for
# dumping later. Define some constants for the table lookup to avoid
# blinding headaches
use constant VMSTAT_AT_STALL       => 0;
use constant VMSTAT_AT_COMPLETE    => 1;
use constant BLOCKSTAT_AT_STALL    => 2;
use constant BLOCKSTAT_AT_COMPLETE => 3;
use constant PROCNAME              => 4;
use constant STACKTRACE            => 5;
use constant STALLFUNCTION         => 6;

use constant NR_WRITEBACK => 0;
use constant NR_DIRTY     => 2;
use constant VMSCAN_WRITE => 1;

sub usage() {
	print("In general, this script is not supported and that includes help.\n");
	exit(0);
}

# Option variables
my $opt_help;
my $opt_output;
my $opt_stapout;
my $opt_accurate_stall = 1;
my $opt_accurate_stack = 0;
GetOptions(
	'help|h'		=> \$opt_help,
	'output|o=s'		=> \$opt_output,
	'stapout|s=s'		=> \$opt_stapout,
	'accurate-stack|a'	=> \$opt_accurate_stack,
	'accurate-stall|a'	=> \$opt_accurate_stall,
);

usage() if $opt_help;
if ($opt_output) {
	open(OUTPUT, ">$opt_output") || die("Failed to open $opt_output for writing");
}
if ($opt_stapout) {
	open(OUTPUT, ">$opt_stapout") || die("Failed to open $opt_stapout for writing");
}

if ($opt_accurate_stack) {
	$opt_accurate_stall = 0;
}
if ($opt_accurate_stall) {
	$opt_accurate_stack = 0;
}

# Handle cleanup of temp files
my $stappid;
my ($handle, $stapscript) = mkstemp("/tmp/stapdXXXXX");
sub cleanup {
	if (defined($stappid)) {
		kill INT => $stappid;
	}
	if (defined($opt_output)) {
		close(OUTPUT);
	}
	unlink($stapscript);
}
sub sigint_handler {
	close(STAP);
	cleanup();
	exit(0);
}
$SIG{INT} = "sigint_handler";

# Build a list of stat files to read. Obviously this is not great if device
# hotplug occurs but that is not expected for the moment and this is lighter
# than running find every time
my @block_iostat_files;
sub d {
	my $file = $File::Find::name;
	return if $file eq "/sys/block";
	push(@block_iostat_files, "$file/stat");
}
find(\&d, ("/sys/block/"));

##
# Read the current stack of a given pid
sub read_stacktrace($) {
	open(STACK, "/proc/$_[0]/stack") || return "Stack unavailable";
	my $stack = do {
		local $/;
		<STACK>;
	};
	close(STACK);
	return $stack;
}

##
# Read information of relevant from /proc/vmstat
sub read_vmstat {
	if (!open(VMSTAT, "/proc/vmstat")) {
		cleanup();
		die("Failed to read /proc/vmstat");
	}

	my $vmstat;
	my ($key, $value);
	my @values;
	while (!eof(VMSTAT)) {
		$vmstat = <VMSTAT>;
		($key, $value) = split(/\s+/, $vmstat);
		chomp($value);

		if ($key eq "nr_writeback") {
			$values[NR_WRITEBACK] = $value;
		}
		if ($key eq "nr_dirty") {
			$values[NR_DIRTY] = $value;
		}
		if ($key eq "nr_vmscan_write") {
			$values[VMSCAN_WRITE] = $value;
		}
	}

	return \@values;
}

##
# Read information from all /sys/block stat files
sub read_blockstat($) {
	my $prefix = $_[0];
	my $stat;
	my $ret;
	
	foreach $stat (@block_iostat_files) {
		if (open(STAT, $stat)) {
			$ret .= sprintf "%s%20s %s", $prefix, $stat, <STAT>;
			close(STAT);
		}
	}
	return $ret;
}

##
# Record a line of output
sub log_output {
	if (defined($opt_output)) {
		print OUTPUT @_;
	}
	print @_;
}

sub log_printf {
	if (defined($opt_output)) {
		printf OUTPUT @_;
	}
	printf @_;
}

sub log_stap {
	if (defined($opt_stapout)) {
		print OUTPUT @_;
	}
}

# Read kernel symbols and add conditional trace functions if they exist
open(KALLSYMS, "/proc/kallsyms") || die("Failed to open /proc/kallsyms");
my $found_get_request_wait = 0;
while (<KALLSYMS>) {
	my ($dummy, $dummy, $symbol) = split(/\s+/, $_);
	my $conditional;
	if ($symbol eq "get_request_wait") {
		push(@trace_functions, $symbol);
		$found_get_request_wait = 1;
		next;
	}
	foreach $conditional (@trace_conditional) {
		if ($symbol eq $conditional) {
			push(@trace_functions, $symbol);
			last;
		}
	}
}
close(KALLSYMS);
if (!$found_get_request_wait) {
	push(@trace_functions, "get_request");
}

# Extract the framework script and fill in the rest
open(SELF, "$0") || die("Failed to open running script");
while (<SELF>) {
	chomp($_);
	if ($_ ne "__END__") {
		next;
	}
	while (<SELF>) {
		print $handle $_;
	}
}
foreach(@trace_functions) {
	print $handle "probe kprobe.function(\"$_\")
{ 
	t=tid()
	name[t]=execname()
	stalled_at[t]=time()
	where[t]=\"$_\"
	delete stalled[t]
}";
}

if ($opt_accurate_stall) {
	# In an ideal world, we would always use a retprobe to catch exactly when
	# the function exited and get a stall time from it. Unfortunately, it mangles
	# the stack trace so we have the option of either accurately tracking stalls
	# or accurately tracking stacks
	foreach(@trace_functions) {
		print $handle "probe kprobe.function(\"$_\").return
{
	t=tid()

	if ([t] in stalled) {
		stall_time = time() - stalled_at[t]
		printf(\"C %d (%s) %d %s %s\\n\", t, name[t], stall_time, time_units, where[t])
	}

	delete stalled[t]
	delete name[t]
	delete stalled_at[t]
	delete where[t]
}"
	}
} else {
	# Alternatively, we try to catch when a stall completes by probing
	# commonly used functions and guessing that when they are called
	# that the operation completed
	foreach(@completion_functions) {
		print $handle "probe kprobe.function(\"$_\").return
{
	t=tid()

	if ([t] in stalled) {
		stall_time = time() - stalled_at[t]
		printf(\"C %d (%s) %d %s %s\\n\", t, name[t], stall_time, time_units, where[t])
	}

	delete stalled[t]
	delete name[t]
	delete stalled_at[t]
	delete where[t]
}";
	}
}

close($handle);

# Contact
$stappid = open(STAP, "stap $stapscript|");
if (!defined($stappid)) {
	die("Failed to execute stap script");
}

# Collect information until interrupted
my %stalled;
while (1) {
	if (eof(STAP)) {
		cleanup();
		die("Unexpected exit of STAP script");
	}

	my $input = <STAP>;
	log_stap($input);
	if ($input !~ /([CS]) ([0-9]*) \((.*)\) ([0-9]*) ms (.*)/) {
		cleanup();
		die("Failed to parse input from stap script\n");
	}

	my $event    = $1;
	my $pid      = $2;
	my $name     = $3;
	my $stalled  = $4;
	my $where    = $5;
	my $recursed = 0;
	
	# Check if we have recursively stalled. This is "impossible" but unless
	# we are using kretprobes, we cannot reliable catch when stalls complete
	if (defined($stalled{$pid}->{NAME}) && $event eq "S") {
		$recursed = 1;
		if ($opt_accurate_stall) {
			cleanup();
			print("Apparently recursing, missing kretprobes.\n");
			print("Process:  $pid ($name)\n");
			print("Stalled:  " . $stalled{$pid}->{STALLFUNCTION} . "\n");
			print($stalled{$pid}->{STACKTRACE});
			print("Stalling: $where\n");
			exit(-1);
		}
	}

	# Record information related to stalls.
	if ($event eq "C" || $recursed) {
		if ($name ne $stalled{$pid}->{NAME}) {
			cleanup();
			die("Processes are changing their identity.");
		}
		if ($where ne $stalled{$pid}->{STALLFUNCTION}) {
			$recursed = 1;
			if ($opt_accurate_stall) {
				cleanup();
				die("The stalling function teleported.");
			}
		}

		# Do not event pretend the stall time is accurate
		if ($recursed) {
			$stalled = -1;
		}

		$stalled{$pid}->{VMSTAT_AT_COMPLETE} = read_vmstat();
		$stalled{$pid}->{BLOCKSTAT_AT_COMPLETE} = read_blockstat("+");
		my $delta_writeback    = $stalled{$pid}->{VMSTAT_AT_COMPLETE}[NR_WRITEBACK] - $stalled{$pid}->{VMSTAT_AT_STALL}[NR_WRITEBACK];
		my $delta_dirty        = $stalled{$pid}->{VMSTAT_AT_COMPLETE}[NR_DIRTY]     - $stalled{$pid}->{VMSTAT_AT_STALL}[NR_DIRTY];
		my $delta_vmscan_write = $stalled{$pid}->{VMSTAT_AT_COMPLETE}[VMSCAN_WRITE] - $stalled{$pid}->{VMSTAT_AT_STALL}[VMSCAN_WRITE];

		# Blind stab in the dark as to what is going on
		my $status;
		if ($where eq "balance_dirty_pages") {
			$status = "DirtyThrottled";
		} else {
			$status = "IO";
		}
		if ($delta_writeback < 0) {
			$status = "${status}_WritebackInProgress";
		}
		if ($delta_writeback > 0) {
			$status = "${status}_WritebackSlow";
		}

		log_output("time " . time() . ": $pid ($name) Stalled: $stalled ms: $where\n");
		log_output("Guessing: $status\n");
		log_printf("-%-15s %12d\n", "nr_dirty",        $stalled{$pid}->{VMSTAT_AT_STALL}[NR_DIRTY]);
		log_printf("-%-15s %12d\n", "nr_writeback",    $stalled{$pid}->{VMSTAT_AT_STALL}[NR_WRITEBACK]);
		log_printf("-%-15s %12d\n", "nr_vmscan_write", $stalled{$pid}->{VMSTAT_AT_STALL}[VMSCAN_WRITE]);
		log_printf("%s", $stalled{$pid}->{BLOCKSTAT_AT_STALL});
		log_printf("+%-15s %12d %12d\n", "nr_dirty",
			$stalled{$pid}->{VMSTAT_AT_COMPLETE}[NR_DIRTY], $delta_dirty);
		log_printf("+%-15s %12d %12d\n", "nr_writeback",
			$stalled{$pid}->{VMSTAT_AT_COMPLETE}[NR_WRITEBACK], $delta_writeback);
		log_printf("+%-15s %12d %12d\n", "nr_vmscan_write",
			$stalled{$pid}->{VMSTAT_AT_COMPLETE}[VMSCAN_WRITE],
			$delta_vmscan_write);
		log_printf("%s", $stalled{$pid}->{BLOCKSTAT_AT_COMPLETE});
		log_output($stalled{$pid}->{STACKTRACE});

		delete($stalled{$pid});
	}

	if ($event eq "S") {
		$stalled{$pid}->{NAME} = $name;
		$stalled{$pid}->{STACKTRACE} = read_stacktrace($pid);
		$stalled{$pid}->{VMSTAT_AT_STALL} = read_vmstat();
		$stalled{$pid}->{BLOCKSTAT_AT_STALL} = read_blockstat("-");
		$stalled{$pid}->{STALLFUNCTION} = $where;
	}
}

cleanup();
exit(0);
__END__
function time () { return gettimeofday_ms() }
global stall_threshold = 1000
global time_units = "ms"
global name, stalled_at, stalled, where

probe timer.profile {
	foreach (tid+ in stalled_at) {
		if ([tid] in stalled) continue

		stall_time = time() - stalled_at[tid]
		if (stall_time >= stall_threshold) {
			printf ("S %d (%s) %d %s %s\n", tid, name[tid], stall_time, time_units, where[tid])
			stalled[tid] = 1 # defer further reports to wakeup
		}
	}
}

