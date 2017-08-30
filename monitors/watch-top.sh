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

		if (!defined $cpu_column && $filter =~ /%CPU/) {
			foreach my $idx (0 .. @elements-1) {
				if ($elements[$idx] eq "%CPU") {
					$cpu_column = $idx;
					last;
				}
			}
		}

		if ($elements[0] !~ /[0-9]+/ || (defined $cpu_column && $elements[$cpu_column] != 0)) {
			print $line;
		}
	}'
fi
