#!/usr/bin/perl
# This parses a file tracing sched_migrate_task and reports socket migration
# patterns using numactl output to map CPU ids to NUMA nodes

use strict;
use Getopt::Long;

# Option variables
my ($opt_numactl);
my ($opt_trace);
my ($opt_printmapping);

GetOptions(
	'--numactl=s'		=> \$opt_numactl,
	'--trace=s'		=> \$opt_trace,
	'--print-mapping'	=> \$opt_printmapping,
);

my %cpu_node;

# Parse numactl
die if !defined $opt_numactl;
if ($opt_numactl =~ /\.gz$/) {
	open(INPUT, "gunzip -c $opt_numactl|") || die("Failed to open numactl output $opt_numactl");
} else {
	open(INPUT, $opt_numactl) || die("Failed to open numactl output $opt_numactl");
}
while (!eof(INPUT)) {
	my $line = <INPUT>;
	next if $line !~ /^node ([0-9]*) cpus: (.*)/;

	my $node = $1;
	for my $cpu (split(/\s/, $2)) {
		$cpu_node{$cpu} = $node;
	}
}
close INPUT;

if ($opt_printmapping || !defined $opt_trace) {
	foreach my $cpu (sort {$a <=> $b} keys %cpu_node) {
		print "$cpu $cpu_node{$cpu}\n";
	}
	exit 0;
}

if ($opt_trace =~ /\.gz$/) {
	open(INPUT, "gunzip -c $opt_trace|") || die("Failed to open trace file $opt_trace");
} else {
	open(INPUT, $opt_trace) || die("Failed to open trace file $opt_trace");
}
while (!eof(INPUT)) {
	my $line = <INPUT>;
	next if ($line !~ /.*sched_migrate_task: (.*)/);

	my $trace_event = $1;
	my @elements = split(/ /, $trace_event);
	for (my $i = 0; $i <= $#elements; $i++) {
		$elements[$i] =~ s/.*=//;
	}

	my $comm = "$elements[0]-$elements[1]";
	my $src = $cpu_node{$elements[3]};
	my $dst = $cpu_node{$elements[4]};
	my $same = "    ";
	$same = "same" if $src == $dst;
	print "$comm $same S$src S$dst\n";
}
close(INPUT);
exit 0;

