#!/bin/bash
# BinDepend: top:procps

# By default, this monitor will _only_ track kswapd tasks. This is because
# the comparison scripts are able to deal only with that (for now).
#
# If wanting to see all the tasks in the monitor logs, add this in
# your config file:
#  export MONITOR_TOP_KSWAPDONLY="no"

FILTERPIDS=
TOPOPTIONS="-b"

if [ "$MONITOR_TOP_ACTIVEONLY" = "" ]; then
	MONITOR_TOP_ACTIVEONLY=yes
fi

if [ "$MONITOR_TOP_SHOWTHREADS" = "yes" ]; then
	TOPOPTIONS="$TOPOPTIONS -H "
fi

if [ "$MONITOR_TOP_KSWAPDONLY" = "" -o "$MONITOR_TOP_KSWAPDONLY" = "yes" ]; then
	for KSWAPD_PID in `ps auxw | grep -E '\[kswapd[0-9]*\]' | awk '{print $2}'`; do
		FILTERPIDS="$FILTERPIDS -p $KSWAPD_PID"
	done
fi

TOPOPTIONS="$TOPOPTIONS $FILTERPIDS"

if [ "$MONITOR_TOP_ACTIVEONLY" != "yes" ]; then
	exec top $TOPOPTIONS -d $MONITOR_UPDATE_FREQUENCY | perl -e 'select(STDOUT);
		$|=1;
		while (<>) {
			if ($_ =~ /^top -.*/) {
				print "time: " . time . " full\n";
			}
			print $_;
		}'
else
	exec top $TOPOPTIONS -d $MONITOR_UPDATE_FREQUENCY | perl -e 'select(STDOUT);
		$|=1;
		while (<>) {
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
