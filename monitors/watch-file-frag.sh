#!/bin/bash

if [ "$SHELLPACK_DATA" = "" -o ! -e "$SHELLPACK_DATA" ]; then
	echo Test directory SHELLPACK_DATA \($SHELLPACK_DATA\) not specified or does not exist
	exit -1
fi
cd $SHELLPACK_DATA
if [ $? -ne 0 ]; then
	echo Test directory SHELLPACK_DATA \($SHELLPACK_DATA\) could not be used
	exit -1
fi

IFS="
"

while [ 1 ]; do
	NR_FILE=0
	NR_EXTENTS=0
	MAX_EXTENTS=0
	MAX_EXTENT_FILE=""

	for FILE in `find -type f`; do
		NR_FILE=$((NR_FILE+1))
		NR_EXTENT=`filefrag "$FILE" | awk -F : '{print $2}' | awk '{print $1}'`
		if [ $NR_EXTENT -gt $MAX_EXTENTS ]; then
			MAX_EXTENTS=$NR_EXTENT
			MAX_EXTENT_FILE=$FILE
		fi
		NR_EXTENTS=$((NR_EXTENTS+NR_EXTENT))
	done
		
	echo `date +%s` $NR_FILE $NR_EXTENTS $MAX_EXTENTS $MAX_EXTENT_FILE
	sleep $MONITOR_UPDATE_FREQUENCY
done
