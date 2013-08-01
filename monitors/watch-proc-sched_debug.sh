#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	cat /proc/sched_debug
	sleep $MONITOR_UPDATE_FREQUENCY
done
