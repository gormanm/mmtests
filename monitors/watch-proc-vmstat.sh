#!/bin/bash
# BinDepend:
while [ 1 ]; do
	echo time: `date +%s`
	cat /proc/vmstat
	sleep $MONITOR_UPDATE_FREQUENCY
done
