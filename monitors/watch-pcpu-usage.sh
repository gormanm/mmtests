#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	ps -eo pid,pcpu,cmd
	sleep $MONITOR_UPDATE_FREQUENCY
done
