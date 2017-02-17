#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	df -k
	sleep $MONITOR_UPDATE_FREQUENCY
done
