#!/bin/bash

if [ "$MONITOR_PERF_EVENTS" = "" ]; then
	echo ERROR: Did not specify MONITOR_PERF_EVENTS in log
	exit -1
fi

# Run perf sched system-wide 
exec perf record -e $MONITOR_PERF_EVENTS -o $MONITOR_LOG \
	perl -e "open(OUTPUT, \">$MONITOR_PID\"); print OUTPUT \$\$; close OUTPUT; sleep;"
