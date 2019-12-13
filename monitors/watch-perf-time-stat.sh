#!/bin/bash

install-depends perf

EVENTS_COMMAND=
if [ "$MONITOR_PERF_EVENTS" != "" ]; then
	EVENTS_COMMAND="-e $MONITOR_PERF_EVENTS"
fi

# Run perf sched for small durations to build picture up over time
while [ 1 ]; do
	echo time: `date +%s`
	perf stat -a $EVENTS_COMMAND sleep $MONITOR_UPDATE_FREQUENCY 2>&1
done
