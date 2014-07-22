#!/usr/bin/perl

use strict;
die if !defined $ARGV[0];
die if !defined $ARGV[1];

my @ht_list;
my @sibling_list;

open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$ARGV[0]/topology/thread_siblings_list") ||
	open(INPUT, "/sys/devices/system/cpu/cpu$ARGV[0]/topology/thread_siblings_list") ||
 	die("Failed to open core topology file for CPU $ARGV[0]");
while (!eof(INPUT)) {
	my $line = <INPUT>;

	foreach my $range (split /,/, $line) {
		chomp($range);
		if ($line =~ /-/) {
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

open(INPUT, "/sys/bus/cpu/drivers/processor/cpu$ARGV[0]/topology/core_siblings_list") ||
	open(INPUT, "/sys/devices/system/cpu/cpu$ARGV[0]/topology/core_siblings_list") ||
	die("Failed to open core topology file for CPU $ARGV[0]");
while (!eof(INPUT)) {
	my $line = <INPUT>;

	foreach my $range (split /,/, $line) {
		chomp($range);
		if ($line =~ /-/) {
			my ($from, $to) = split(/-/, $range);
			for (my $i = $from; $i <= $to; $i++) {
				if ($i == $ARGV[0] || grep {$_ == $i} @ht_list) {
					next;
				}
				push @sibling_list, $i;
			}
		} else {
			if ($range != $ARGV[0] || grep {$_ == $range} @ht_list) {
				push @sibling_list, $range;
			}
		
		}
	}
}


if ($ARGV[1] eq "threads") {
	print join ",", @ht_list;
} elsif ($ARGV[1] eq "cores") {
	print join ",", @sibling_list;
} else {
	die("Did not recognise attribute");
}



