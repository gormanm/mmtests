#!/usr/bin/perl

use strict;
die if !defined $ARGV[0];
die if !defined $ARGV[1];
die if !defined $ARGV[2];

my @ht_list;
my @node_core_list;
my @sibling_list;
my @llc_core_list;

open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$ARGV[0]/topology/thread_siblings_list") ||
	open(INPUT, "/sys/devices/system/cpu/cpu$ARGV[0]/topology/thread_siblings_list") ||
 	die("Failed to open core topology file for CPU $ARGV[0]");
while (!eof(INPUT)) {
	my $line = <INPUT>;

	foreach my $range (split /,/, $line) {
		chomp($range);
		if ($range =~ /-/) {
			my ($from, $to) = split(/-/, $range);
			for (my $i = $from; $i <= $to; $i++) {
				if ($i == $ARGV[0]) {
					next;
				}
				push @ht_list, $i;
			}
		} else {
			if ($range != $ARGV[0]) {
				push @ht_list, $range;
			}
		
		}
	}
}
close INPUT;

open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$ARGV[0]/node$ARGV[2]/cpulist") ||
	open(INPUT, "/sys/devices/system/cpu/cpu$ARGV[0]/node$ARGV[2]/cpulist") ||
	die("Failed to open node cpulist file for CPU $ARGV[0]");
while (!eof(INPUT)) {
	my $line = <INPUT>;

	foreach my $range (split /,/, $line) {
		chomp($range);
		if ($range =~ /-/) {
			my ($from, $to) = split(/-/, $range);
			for (my $i = $from; $i <= $to; $i++) {
				if ($i == $ARGV[0] || grep {$_ == $i} @ht_list) {
					next;
				}
				push @node_core_list, $i;
			}
		} else {
			if ($range != $ARGV[0] && ! grep {$_ == $range} @ht_list) {
				push @node_core_list, $range;
			}
		}
	}
}
close INPUT;

open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$ARGV[0]/topology/core_siblings_list") ||
	open(INPUT, "/sys/devices/system/cpu/cpu$ARGV[0]/topology/core_siblings_list") ||
	die("Failed to open core topology file for CPU $ARGV[0]");
while (!eof(INPUT)) {
	my $line = <INPUT>;

	foreach my $range (split /,/, $line) {
		chomp($range);
		if ($range =~ /-/) {
			my ($from, $to) = split(/-/, $range);
			for (my $i = $from; $i <= $to; $i++) {
				if ($i == $ARGV[0] || grep {$_ == $i} @ht_list) {
					next;
				}
				push @sibling_list, $i;
			}
		} else {
			if ($range != $ARGV[0] && ! grep {$_ == $range} @ht_list) {
				push @sibling_list, $range;
			}
		
		}
	}
}
close INPUT;

if (open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$ARGV[0]/cache/index3/shared_cpu_list") ||
    open(INPUT, "/sys/devices/system/cpu/cpu$ARGV[0]/cache/index3/shared_cpu_list")) {
	while (!eof(INPUT)) {
		my $line = <INPUT>;

		foreach my $range (split /,/, $line) {
			chomp($range);
			my ($from, $to) = $range =~ /-/ ?
				split(/-/, $range) : ($range, $range);

			for (my $i = $from; $i <= $to; $i++) {
				if ($i == $ARGV[0] || (grep {$_ == $i} @ht_list) ||
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
} elsif ($ARGV[1] eq "cores") {
	print join ",", @sibling_list;
} elsif ($ARGV[1] eq "llc_cores") {
	print join ",", @llc_core_list;
} else {
	die("Did not recognise attribute");
}



