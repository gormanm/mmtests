#!/bin/bash
OUTPUT=$1

if [ "$OUTPUT" = "" ]; then
	OUTPUT=debug-info-`date +%Y.%m.%d-%H.%M.%S`
fi

echo -n > $OUTPUT
for FILE in /proc/interrupts /proc/cpuinfo /proc/meminfo /proc/buddyinfo /proc/vmstat /proc/zoneinfo /proc/pagetypeinfo /proc/slabinfo; do
	echo :file start $FILE >> $OUTPUT
	cat $FILE >> $OUTPUT
	echo :file end $FILE >> $OUTPUT
done
