#!/bin/bash
#
# This monitor runs sync(1) once in a while and checks how long does it run.
# The goal is that sync(1) doesn't get livelocked by the running workload.

while true; do
	LAT=$(/usr/bin/time -f "%e" sync 2>&1)
	STAMP=$(date +"%s.%N")
	echo $STAMP $LAT
	usleep $((MONITOR_SYNC_LATENCY_SYNCPAUSE_MS*1000))
done
