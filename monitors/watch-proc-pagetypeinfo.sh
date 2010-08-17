#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	cat /proc/pagetypeinfo
	sleep $MONITOR_UPDATE_FREQUENCY
done
