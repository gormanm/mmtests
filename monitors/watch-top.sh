#!/bin/bash
if [ "$MONITOR_TOP_ACTIVEONLY" = "" ]; then
	MONITOR_TOP_ACTIVEONLY=yes
fi
if [ "$MONITOR_TOP_ACTIVEONLY" != "yes" ]; then
	exec top -b -d $MONITOR_UPDATE_FREQUENCY | perl -e 'while (<>) {
		if ($_ =~ /^top -.*/) {
			print "time: " . time . " full\n";
		}
		print $_;
	}'
else
	exec top -b -d $MONITOR_UPDATE_FREQUENCY | perl -e 'while (<>) {
		if ($_ =~ /^top -.*/) {
			print "time: " . time . " short\n";
		}
		my $line = $_;
		my $filter = $line;
		$filter =~ s/^\s+//;

		my @elements = split(/\s+/, $filter);
		if ($elements[0] !~ /[0-9]+/ || $elements[8] != 0) {
			print $line;
		}
	}'
fi
