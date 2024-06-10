#!/usr/bin/perl

use strict;
use Getopt::Long;

my ($opt_print);
my ($opt_latency);
my ($opt_index);
my ($opt_cstate);
GetOptions(
	'print|p'	=> \$opt_print,
	'latency|l=s'	=> \$opt_latency,
	'index|i=s'	=> \$opt_index,
	'cstate|c=s'	=> \$opt_cstate,
);

my %cstate_index;
my %cstate_name;
my %index_name;
my $cpu_dma_latency = -1;

# Read cstate latencies
sub read_cstates() {
	my @cstates;
	my $cpuidle_root = "/sys/devices/system/cpu/cpu0/cpuidle";

	foreach my $state (<$cpuidle_root/state*>) {
		my ($fh, $name, $latency);
		my $index = $state;
		$index =~ s/^state//;

		open $fh, '<', "$state/name" or die "Can't open file $state/state$state/name: $!";
		read $fh, $name, -s $fh;
		chomp($name);
		close($fh);
		open $fh, '<', "$state/latency" or die "Can't open file $state/state$state/latency: $!";
		read $fh, $latency, -s $fh;
		chomp($latency);
		close($fh);

		$state =~ s/.*([0-9]+)$/$1/;

		$cstate_index{$state} = $latency;
		$cstate_name{$state} = $name;
		$index_name{$name} = $state;
	}
}
read_cstates();

sub print_cstates() {
	foreach my $state (sort {$a <=> $b} keys %cstate_index) {
		printf("%-4s %5s %4d\n", "c-$state", $cstate_name{$state}, $cstate_index{$state});
	}
}

# Print available c-states and their latency
print_cstates();
if ($opt_print) {
	exit(0);
}

# Lookup state that meets a particular latency
if (defined $opt_latency) {
	$cpu_dma_latency = $opt_latency;
	print "Setting cpu_dma_latency to $cpu_dma_latency\n";
}

if (defined $opt_index) {
	$cpu_dma_latency = $cstate_index{$opt_index};
	die if $cstate_name{$opt_index} eq "";
	print "Setting cpu_dma_latency for state $opt_index ($cstate_name{$opt_index}) to $cpu_dma_latency\n";
}

if ($opt_cstate) {
	die if $index_name{$opt_cstate} eq "";
	$cpu_dma_latency = $cstate_index{$index_name{$opt_cstate}};
	my $state = $index_name{$opt_cstate};
	print "Setting cpu_dma_latency for state $state ($cstate_name{$state}) to $cpu_dma_latency\n";
}

if ($cpu_dma_latency == -1) {
	exit(0);
}

# Set cpu_dma_latency
open(PID, ">/tmp/mmtests-cstate.pid") || die "Failed to open /tmp/mmtests-cstate.pid";
syswrite PID, $$;
close(PID);
open(FH, ">/dev/cpu_dma_latency") || die "Failed to open cpu_dma_latency";
syswrite FH, pack('i', $cpu_dma_latency) || die "Failed to write cpu_dma_latency";

# Sleep until signal
my $exiting = 0;
local $SIG{INT} = sub { $exiting = 1 };
while (!$exiting) {
	sleep(3600);
}
close(CPU);
unlink("/tmp/mmtests-cstate.pid");
