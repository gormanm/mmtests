#!/bin/bash

install-depends perf

if [ "$MONITOR_PERF_EVENTS" = "" ]; then
	echo ERROR: Did not specify MONITOR_PERF_EVENTS in log
	exit -1
fi

# Run perf sched for small durations to build picture up over time
while [ 1 ]; do
	echo time: `date +%s`
	perf stat -a -e $MONITOR_PERF_EVENTS sleep $MONITOR_UPDATE_FREQUENCY
done
