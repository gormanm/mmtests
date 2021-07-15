#!/bin/bash

if [ ! -e work/testdisk ]; then
	echo No work/testdisk
	exit 0
fi

DEVICE=`df work/testdisk | tail -1 | awk '{print $1}'`
MAJOR_HEX=`stat -c %t $DEVICE`
MAJOR_DEC=$((0x$MAJOR_HEX))
if [ ! -e /sys/kernel/debug/bdi/$MAJOR_DEC:0/stats ]; then
	echo No /sys/kernel/debug/bdi/$MAJOR_DEC:0/stats
	exit 0
fi

while [ 1 ]; do
	echo time: `date +%s`
	cat /sys/kernel/debug/bdi/$MAJOR_DEC:0/stats
	sleep $MONITOR_UPDATE_FREQUENCY
done
