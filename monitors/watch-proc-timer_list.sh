#!/bin/bash
# BinDepend:
while [ 1 ]; do
	echo time: `date +%s`
	cat /proc/timer_list
	sleep $MONITOR_UPDATE_FREQUENCY
done
