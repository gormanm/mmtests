#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`

	for PROC in `\ls -d /proc/[0-9]*`; do
		if [ -e $PROC/status ]; then
			cat $PROC/status
			cat $PROC/stack
		fi
	done
	sleep $MONITOR_UPDATE_FREQUENCY
done
