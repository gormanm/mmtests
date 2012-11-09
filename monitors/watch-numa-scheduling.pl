#!/usr/bin/perl
# Visualise where threads are running and their per-node usage
# Yes, this is a complete hatchet job. It's not a work of art
# we're looking for here

use strict;
my $exiting = 0;
sub sigint_handler {
        $exiting = 1;
}
$SIG{INT} = "sigint_handler";
my $update_frequency = $ENV{"MONITOR_UPDATE_FREQUENCY"};
if ($update_frequency eq "") {
	$update_frequency = 10;
}

# Build numa->cpu table
my %popnode;
my %cpunode;
my $nr_online_nodes;
open(NUMACTL, "numactl --hardware|") || die("Failed to run numactl");
while (!eof(NUMACTL)) {
	my $line = <NUMACTL>;

	if ($line =~ /^node ([0-9]+) cpus: (.*)/) {
		my ($node, $cpus) = ($1, $2);
		$nr_online_nodes++;
		foreach my $cpu (split /\s+/, $cpus) {
			$cpunode{$cpu} = $node;
		}
	}
}
close(NUMACTL);

# Print a header
my $nid;
printf("%5s %5s %-16s %4s %3s", "PID", "TID", "NAME", "CPU", "RN");
printf(" ");
for ($nid = 0; $nid < $nr_online_nodes; $nid++) {
	printf("%3s", "C$nid");
}
for ($nid = 0; $nid < $nr_online_nodes; $nid++) {
	printf("%5s", "N$nid");
}
printf("\n");

while (!$exiting) {
	printf("time: %d\n", time);

	# Build a list of processes and threads. Jeez, proc is a pain in the ass
	# to parse. There must be a better way of discovering threads that this
	# junk.
	my @tids;
	my %threads;
	foreach my $pid (</proc/[0-9]*>) {
		$pid =~ s/.*\///;
		push @tids, $pid;

		foreach my $tid (</proc/$pid/task/[0-9]*>) {
			$tid =~ s/.*\///;
			if ($tid == $pid || $threads{$tid}) {
				next;
			}
			$threads{$tid} = $pid;
			push @tids, $tid;
		}
	}

	my %maps;
	foreach my $tid (@tids) {
		open(STAT, "/proc/$tid/stat");
		my $statline = <STAT>;
		close(STAT);

		my @fields = split(/ /, $statline);
		my $pid = $fields[0];
		if ($threads{$pid}) {
			$pid = $threads{$pid};
		}
		my $cpuid = $fields[38];
		my $fname = $fields[1];
		$fname =~ s/[()]//g;

		printf("%5d %5d %-16s %4d %3d", $pid, $tid, $fname, $cpuid, $cpunode{$cpuid});
		my $running_node = $cpunode{$cpuid};

		printf(" ");
		for ($nid = 0; $nid < $nr_online_nodes; $nid++) {
			if ($nid == $running_node) {
				printf("  X");
			} else {
				printf("  .");
			}
		}

		# Cache the numa_maps on a per-address space where possible
		if ($maps{$pid} eq "") {
			my $map = "";

			# Read /proc/PID/numa_maps
			my $total_pages;
			my @node_pages;

			open(NUMAMAP, "/proc/$pid/numa_maps");
			while (!eof(NUMAMAP)) {
				my $line = <NUMAMAP>;
				if ($line =~ /^([0-9a-fA-F]+) (\S+)(.*)/) {
					my ($address, $dummy, $flags) = ($1, $2, $3);
					$line =~ s/^\s+|\s+$//g;
					foreach my $flag (split /\s/, $flags) {
						if ($flag =~ /N([0-9]+)=([0-9]+)/) {
							$total_pages += $2;
							$node_pages[$1] += $2;
						}
					}
				}
			}
			close(NUMAMAP);
			$map .= " ";

			my $bestnode = -1;
			my $bestpercentage = -1;
			if ($total_pages != 0) {
				for ($nid = 0; $nid < $nr_online_nodes; $nid++) {
					my $percentage = $node_pages[$nid] * 100 / $total_pages;
					$map .= sprintf("%3d%% ", $percentage);
					if ($percentage >  $bestpercentage) {
						$bestpercentage = $percentage;
						$bestnode = $nid;
					}
				}
			} else {
				$bestnode = $cpunode{$cpuid};
			}
			$maps{$pid} = $map;
			$popnode{$pid} = $bestnode;
		}

		printf("%s", $maps{$pid});

		if ($popnode{$pid} != $cpunode{$cpuid}) {
			print " STUPID $cpunode{$cpuid} != $popnode{$pid}"
		}
		printf("\n");
	}
	sleep($update_frequency);
}
