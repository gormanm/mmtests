#!/usr/bin/perl
# This is a very direct perl script to merge two arbitrary ftrace events together and
# maintain the stack trace of the first event. It was built to workaround bugs in
# perf inject for scheduler-related events and is highly specialised

use strict;

my $start_event = $ARGV[0];
my $end_event = $ARGV[1];
my $field = $ARGV[2];

if ($start_event eq "") {
	$start_event = "sched:sched_switch:";
}

if ($end_event eq "") {
	$end_event = "sched:sched_stat_sleep:";
}
if ($field eq "") {
	$field = "delay="
}

my %merged_event;
my %stacktrace;

my $id = "";
my $reading_trace = 0;
while (!eof(STDIN)) {
	my $line = <STDIN>;

	if ($line =~ /^[0-9a-zA-Z]/) {
		my @elements = split(/\s+/, $line);

		my $event = $elements[5];

		$id = "$elements[0]-$elements[1]";
		$reading_trace = 0;
		if ($event eq $start_event) {
			$merged_event{$id} = $line;
			chomp($merged_event{$id});
			$merged_event{$id} .= " :: ";
			$stacktrace{$id} = "";
			$reading_trace = 1;
		}

		if ($event eq $end_event) {
			if ($merged_event{$id} ne "") {

				$line =~ s/.*$end_event/$end_event/;
				$merged_event{$id} .= $line;
				my @elements = split(/\s+/, $merged_event{$id});

				for (my $i = 0; $i < $#elements; $i++) {
					if ($elements[$i] =~ /$field/) {
						my $dummy;
						($dummy, $elements[4]) = split(/=/, $elements[$i]);
					}
				}

				foreach my $element (@elements) {
					printf "%-12s ", $element;
				}
				print "\n";

				print $stacktrace{$id};
				$id = "";
			}
		}

		next;
	}

	if ($reading_trace) {
		$stacktrace{$id} .= $line;
	}
}
