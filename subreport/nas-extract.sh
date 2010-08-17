#!/bin/bash

if [ "$1" = "" ]; then
	echo Specify a directory
	exit -1
fi

COUNT=0
for LOG in `ls $1/*.log`; do
	CLASS=`grep "^ Class" $LOG | awk '{print $3}'`
	#RESULT=`grep "Mop/s total" $LOG | awk '{print $4}'`
	RESULT=`grep "Time in seconds" $LOG | awk '{print $5}'`
	COUNT=$((COUNT+1))
	NAME=`basename $LOG | sed -e 's/\..*//'`
	echo "$NAME.$CLASS	$COUNT	$RESULT"
done
