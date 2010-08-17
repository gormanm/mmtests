#!/bin/bash
PSWPIN=`grep "pswpin " /proc/vmstat | awk '{print $2}'`
PSWPOUT=`grep "pswpout " /proc/vmstat | awk '{print $2}'`
LAST_SWAPIO=$(($PSWPIN+$PSWPOUT))
while [ 1 ]; do
	PSWPIN=`grep "pswpin " /proc/vmstat | awk '{print $2}'`
	PSWPOUT=`grep "pswpout " /proc/vmstat | awk '{print $2}'`
	SWAPIO=$(($PSWPIN+$PSWPOUT))
	SWAPIO_DIFF=$(($SWAPIO-$LAST_SWAPIO))
	LAST_SWAPIO=$SWAPIO
	echo "swapio $SWAPIO_DIFF"
	sleep $MONITOR_UPDATE_FREQUENCY
done
