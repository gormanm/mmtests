#!/bin/bash
while [ 1 ]; do
	grep "nr_writeback " /proc/vmstat
	sleep $MONITOR_UPDATE_FREQUENCY
done
