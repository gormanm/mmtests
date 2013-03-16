#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`

	for PID in `ps aux | grep -E kswapd[0-9] | grep -v grep | awk '{print $2}'`; do
		if [ -e /proc/$PID/status ]; then
			echo $PID `head -1 /proc/$PID/status | awk '{print $2}'`
			cat /proc/$PID/stack
		fi
	done
	sleep $MONITOR_UPDATE_FREQUENCY
done
