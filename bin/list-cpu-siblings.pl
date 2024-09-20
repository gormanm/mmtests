#!/usr/bin/perl

use strict;
die "Must specify CPU as first argument"					if !defined $ARGV[0];
die "Must specify threads|node_cores|llc_cores as second argument"		if !defined $ARGV[1];
die "Must specify NUMA node of CPU as third argument"				if !defined $ARGV[2];

my @ht_list;
my @node_core_list;
my @llc_core_list;

my $target_cpu = $ARGV[0];
die "CPU $target_cpu does not exist or cannot be examined" if ! -e "/sys/bus/cpu/drivers/processor/cpu$target_cpu";

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

open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$target_cpu/node$ARGV[2]/cpulist") ||
	open(INPUT, "/sys/devices/system/cpu/cpu$target_cpu/node$ARGV[2]/cpulist") ||
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


if ($ARGV[1] eq "threads") {
	print join ",", @ht_list;
} elsif ($ARGV[1] eq "node_cores") {
	print join ",", @node_core_list;
} elsif ($ARGV[1] eq "llc_cores") {
	print join ",", @llc_core_list;
} else {
	die("Did not recognise attribute");
}



