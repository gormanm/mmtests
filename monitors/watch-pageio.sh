#!/bin/bash

PGPGIN=`grep "pgpgin " /proc/vmstat | awk '{print $2}'`
PGPGOUT=`grep "pgpgout " /proc/vmstat | awk '{print $2}'`
LAST_PAGEIO=$(($PGPGIN+$PGPGOUT))
while [ 1 ]; do
	PGPGIN=`grep "pgpgin " /proc/vmstat | awk '{print $2}'`
	PGPGOUT=`grep "pgpgout " /proc/vmstat | awk '{print $2}'`
	PAGEIO=$(($PGPGIN+$PGPGOUT))
	PAGEIO_DIFF=$(($PAGEIO-$LAST_PAGEIO))
	LAST_PAGEIO=$PAGEIO
	echo "pageio $PAGEIO_DIFF"
	sleep $MONITOR_UPDATE_FREQUENCY
done
