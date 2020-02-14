#!/bin/bash

if [ -e /proc/sys/kernel/sched_schedstats ]; then
	echo 1 > /proc/sys/kernel/sched_schedstats
fi

while [ 1 ]; do
	echo time: `date +%s`
	cat /proc/schedstat
	sleep $MONITOR_UPDATE_FREQUENCY
done
