#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	mpstat -P ALL -u
	sleep $MONITOR_UPDATE_FREQUENCY
done
