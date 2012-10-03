#!/bin/bash

NODES=`grep ^Node /proc/zoneinfo | awk '{print $2}' | sed -e 's/,//' | sort | uniq`
while [ 1 ]; do
	echo time: `date +%s`
	for NODE in $NODES; do
		echo node: $NODE
		cat /sys/devices/system/node/node$NODE/meminfo
	done
	sleep $MONITOR_UPDATE_FREQUENCY
done
