#!/bin/bash

# Handle being shutdown
EXITING=0
shutdown_read() {
	echo 0 > /proc/sys/kernel/latencytop
	EXITING=1
	exit 0
}
trap shutdown_read SIGTERM
trap shutdown_read SIGINT

echo 1 > /proc/sys/kernel/latencytop
echo 0 > /proc/latency_stats

while [ 1 ]; do
        # Check if we should shutdown 
        if [ $EXITING -eq 1 ]; then 
                exit 0 
        fi 

	echo
	echo time: `date +%s`
	sort -n -k2 /proc/latency_stats
	sleep $MONITOR_UPDATE_FREQUENCY
done
