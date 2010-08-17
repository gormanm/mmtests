#!/bin/bash

PGPGIN=`grep "pgpgin " /proc/vmstat | awk '{print $2}'`
PGPGOUT=`grep "pgpgout " /proc/vmstat | awk '{print $2}'`
PSWPIN=`grep "pswpin " /proc/vmstat | awk '{print $2}'`
PSWPOUT=`grep "pswpout " /proc/vmstat | awk '{print $2}'`
LAST_TOTALIO=$(($PGPGIN+$PGPGOUT+$PSWPIN+$PSWPOUT))
while [ 1 ]; do
	PGPGIN=`grep "pgpgin " /proc/vmstat | awk '{print $2}'`
	PGPGOUT=`grep "pgpgout " /proc/vmstat | awk '{print $2}'`
	PSWPIN=`grep "pswpin " /proc/vmstat | awk '{print $2}'`
	PSWPOUT=`grep "pswpout " /proc/vmstat | awk '{print $2}'`
	TOTALIO=$(($PGPGIN+$PGPGOUT+$PSWPIN+$PSWPOUT))
	TOTALIO_DIFF=$(($TOTALIO-$LAST_TOTALIO))
	LAST_TOTALIO=$TOTALIO
	echo "totalio $TOTALIO_DIFF"
	sleep $MONITOR_UPDATE_FREQUENCY
done
