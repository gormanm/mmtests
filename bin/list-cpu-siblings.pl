#!/usr/bin/perl

use strict;
die "Must specify CPU as first argument"					if !defined $ARGV[0];
die "Must specify threads|llc_cores|node_cores as second argument"		if !defined $ARGV[1];

my @ht_list;
my @node_core_list;
my @llc_core_list;

# Sanity check target CPU argument
my $target_cpu = $ARGV[0];
my $target_topology = $ARGV[1];
die "CPU $target_cpu does not exist or cannot be examined" if ! -e "/sys/bus/cpu/drivers/processor/cpu$target_cpu";

# Auto-detect NUMA node if not specified.
my $target_node = $ARGV[2];
if (!defined $target_node) {
	my @node_dirs = </sys/bus/cpu/drivers/processor/cpu$target_cpu/node*>;
	die "Core belongs to multiple nodes?!? Must specify correct node as third argument" if $#node_dirs > 0;
	$target_node = $node_dirs[0];
	$target_node =~ s/.*([0-9]+)$/\1/;
	die "Unable to discover node information" if ! -e "/sys/bus/cpu/drivers/processor/cpu$target_cpu/node$target_node";
}

# Identify SMT siblings of target_cpu
open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$target_cpu/topology/thread_siblings_list") ||
	open(INPUT, "/sys/devices/system/cpu/cpu$target_cpu/topology/thread_siblings_list") ||
	die("Failed to open core topology file for CPU $target_cpu");
while (!eof(INPUT)) {
	my $line = <INPUT>;

	foreach my $range (split /,/, $line) {
		chomp($range);
		if ($range =~ /-/) {
			my ($from, $to) = split(/-/, $range);
			for (my $i = $from; $i <= $to; $i++) {
				if ($i == $target_cpu) {
					next;
				}
				push @ht_list, $i;
			}
		} else {
			if ($range != $target_cpu) {
				push @ht_list, $range;
			}
		
		}
	}
}
close INPUT;

# Identify CPUs on the same node as target_cpu that are not SMT siblings
open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$target_cpu/node$target_node/cpulist") ||
	open(INPUT, "/sys/devices/system/cpu/cpu$target_cpu/node$target_node/cpulist") ||
	die("Failed to open node cpulist file for CPU $target_cpu");
while (!eof(INPUT)) {
	my $line = <INPUT>;

	foreach my $range (split /,/, $line) {
		chomp($range);
		if ($range =~ /-/) {
			my ($from, $to) = split(/-/, $range);
			for (my $i = $from; $i <= $to; $i++) {
				if ($i == $target_cpu || grep {$_ == $i} @ht_list) {
					next;
				}
				push @node_core_list, $i;
			}
		} else {
			if ($range != $target_cpu && ! grep {$_ == $range} @ht_list) {
				push @node_core_list, $range;
			}
		}
	}
}
close INPUT;

# Identify CPUs sharing a Last Level Cache (LLC) that are not SMT siblings
if (open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$target_cpu/cache/index3/shared_cpu_list") ||
    open(INPUT, "/sys/devices/system/cpu/cpu$target_cpu/cache/index3/shared_cpu_list")) {
	while (!eof(INPUT)) {
		my $line = <INPUT>;

		foreach my $range (split /,/, $line) {
			chomp($range);
			my ($from, $to) = $range =~ /-/ ?
				split(/-/, $range) : ($range, $range);

			for (my $i = $from; $i <= $to; $i++) {
				if ($i == $target_cpu || (grep {$_ == $i} @ht_list) ||
				    ! grep {$_ == $i} @node_core_list) {
					next;
				}
				push @llc_core_list, $i;
			}
		}
	}

	close INPUT;
}

if (! @llc_core_list)  {
	@llc_core_list = @node_core_list;
}


if ($target_topology eq "threads") {
	print join ",", @ht_list;
} elsif ($target_topology eq "llc_cores") {
	print join ",", @llc_core_list;
} elsif ($target_topology eq "node_cores") {
	print join ",", @node_core_list;
} else {
	die("Did not recognise attribute");
}



