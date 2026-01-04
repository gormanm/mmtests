#!/usr/bin/perl

use strict;
use Time::HiRes qw/ time sleep /;

open(SQLITE, "|./bin/sqlite3 $ARGV[0]") || die("Failed to exec sqlite3");
open(INPUT, "$ARGV[1]") || die("Failed to open script $ARGV[1]");

my $threshold = 2;
my $nr_trans = 0;
my $last_trans = 0;
my $start_time = time;
my $last_time = $start_time;

while (!eof(INPUT)) {
	my $line = <INPUT>;
	print SQLITE $line;
	$nr_trans++;

	my $current_time = time;
	my $time_diff = $current_time - $last_time;
	my $total_time = $current_time - $start_time;
	if ($time_diff > 0.5) {
		my $txn = ($nr_trans - $last_trans);
		my $txn_per_second = ($nr_trans - $last_trans) / $time_diff;

		my $type = "execute";
		if ($total_time < $threshold) {
			$type = "warmup ";
		}

		printf "$type %12.2f %12.2f %12d %12.3f\n", $total_time, $time_diff, $txn, $txn_per_second;
		$last_time = $current_time;
		$last_trans = $nr_trans;
	}
}

close(INPUT);
close(SQLITE);
