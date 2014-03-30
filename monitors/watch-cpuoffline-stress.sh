#!/bin/bash

# Assumes sequential ordering of CPUs. This is not always true but
# sufficient for the test in mind
NUMCPUS=`ls -d /sys/devices/system/cpu/cpu[0-9]* | wc -l`
MAX_CPU_INDEX=$((NUMCPUS-1))

while [ 1 ]; do
	OFFLINED=0
	for CPU in `seq 1 $MAX_CPU_INDEX`; do
		echo 0 > /sys/devices/system/cpu/cpu$CPU/online
		STATUS=`cat /sys/devices/system/cpu/cpu$CPU/online`
		if [ "$STATUS" = "0" ]; then
			OFFLINED=$((OFFLINED+1))
		fi
	done

	ONLINED=0
	for CPU in `seq 1 $MAX_CPU_INDEX`; do
		echo 1 > /sys/devices/system/cpu/cpu$CPU/online
		STATUS=`cat /sys/devices/system/cpu/cpu$CPU/online`
		if [ "$STATUS" = "1" ]; then
			ONLINED=$((ONLINED+1))
		fi
	done

	echo cpuhotplug $NUMCPUS $OFFLINED $ONLINED
done
