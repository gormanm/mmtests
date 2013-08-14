#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	cat /proc/interrupts
	sleep $MONITOR_UPDATE_FREQUENCY
done
