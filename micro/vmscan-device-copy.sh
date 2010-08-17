#!/bin/bash
# Benchmark is just the most basic copy that can highlight when kswapd is
# being aggressive. Monitor free memory for different values of min_free_kbytes
# and draw conclusions
#
# Copyright Mel Gorman 2011
echo Dropping caches
echo 3 > /proc/sys/vm/drop_caches

if [ "$MICRO_VMSCAN_DEVICE_COPY_LIMIT_MB" = "" ]; then
	echo Copying $1
	time cp $1 /dev/null
else
	echo Copying ${MICRO_VMSCAN_DEVICE_COPY_LIMIT_MB}MB from $1
	dd if=$1 of=/dev/null ibs=1048576 count=$MICRO_VMSCAN_DEVICE_COPY_LIMIT_MB
fi
