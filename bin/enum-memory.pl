#!/usr/bin/perl
# Script to enumerate available memory banks reverse ordered
# by physical address and interleaving node IDs
use strict;

my %bank_phys;
my %phys_node;
my %phys_bank;

# FLAT: my @active_phys;
my %active_phys_node;

foreach my $memdir (</sys/devices/system/memory/memory*>) {
	my $nr_nid;
	my $nid;
	my $phys_index;
	my $bank = $memdir =~ s/.*memory//r;

	# Discover and validate node ID
	foreach my $nodedir (<$memdir/node*>) {
		$nid = $nodedir =~ s/.*node//r;
		$nr_nid++;
	}
	if ($nr_nid > 1) {
		print STDERR "Ignoring memory bank $bank as it spans $nr_nid nodes\n";
		next;
	}

	my $phys_index = hex (do { local( @ARGV, $/ ) = "$memdir/phys_index" ; <> });

	$phys_bank{$phys_index} = $bank;
	$phys_node{$phys_index} = $nid;

	# FLAT: push @active_phys, $phys_index;
	push @{$active_phys_node{$nid}}, $phys_index;
}

# FLAT: @active_phys = sort { $b <=> $a } @active_phys;

# Sort indicies from each node into flat arrays
my @node_banks;
foreach my $nid (sort { $a <=> $b } keys %active_phys_node) {
	my @indices = sort { $b <=> $a } @{$active_phys_node{$nid}};
	push @node_banks, \@indices;
}

# "Zip" the arrays for each node
my $nr_remaining = -1;
while ($nr_remaining != 0) {
	$nr_remaining = 0;
	foreach my $node_ref (@node_banks) {
		my $phys = shift @{$node_ref};
		if (defined $phys) {
			print "$phys_bank{$phys}\n";
			$nr_remaining++;
		}
	}
}
