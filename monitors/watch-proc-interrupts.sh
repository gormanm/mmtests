#!/bin/bash
# BinDepend:
[ $MONITOR_UPDATE_FREQUENCY -lt 10 ] && MONITOR_UPDATE_FREQUENCY=10
while [ 1 ]; do
	echo time: `date +%s`
	cat /proc/interrupts
	sleep $MONITOR_UPDATE_FREQUENCY
done
