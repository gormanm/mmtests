#!/bin/bash
cd /proc
while [ 1 ]; do
	echo time: `date +%s`

	for PROC in [0-9]*; do
		LIST=
		if [ -e /proc/$PROC/status ]; then
			LIST="/proc/$PROC/stat"
		fi

		# Now process all its threads
		for THREAD_PROC in /proc/$PROC/task/[0-9]*; do
			if [ "$THREAD_PROC" = "/proc/$PROC/task/$PROC" ]; then
				continue
			fi
			LIST="$LIST $THREAD_PROC/stat"
		done
		cat $LIST 2> /dev/null
	done
	exit
	sleep $MONITOR_UPDATE_FREQUENCY
done
