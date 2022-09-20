#!/bin/bash

SCHED_DEBUG="/proc/sched_debug"
if [ -e $SCHED_DEBUG ]; then
	SCHED_DEBUG="/sys/kernel/debug/sched/debug"
fi
while [ 1 ]; do
	echo time: `date +%s`
	cat $SCHED_DEBUG
	sleep $MONITOR_UPDATE_FREQUENCY
done
