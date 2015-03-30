#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	tail -n +3 /proc/net/dev | tr -d ':'
	sleep $MONITOR_UPDATE_FREQUENCY
done
