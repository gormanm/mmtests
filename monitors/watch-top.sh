#!/bin/bash
exec top -b -d $MONITOR_UPDATE_FREQUENCY | perl -e 'while (<>) {
	if ($_ =~ /^top -.*/) {
		print "time: " . time . "\n";
	}
	print $_;}'
