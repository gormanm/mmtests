#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	exec top -b -d $MONITOR_UPDATE_FREQUENCY -n 2 | perl -e 'while (<>) {
		if ($_ =~ /^top -.*/) {
			print "time: " . time . "\n$_";
		}
		print $_;}'
done
