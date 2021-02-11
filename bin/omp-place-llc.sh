#!/bin/bash

for FILE in `find /sys/devices/system/cpu -name "shared_cpu_list" | grep index3`; do
	ENTRY=`cat $FILE`
	ENTRY=`echo $ENTRY | sed -e 's/,/ /g'`

	OMPPLACE=
	for RANGE in $ENTRY; do
		FROM=`echo $RANGE | awk -F - '{print $1}'`
		TO=`echo $RANGE | awk -F - '{print $2}'`
		SPAN=$((TO-FROM+1))
		if [ "$OMPPLACE" != "" ]; then
			OMPPLACE+=","
		fi
		OMPPLACE+="$FROM:$SPAN"
	done
	echo "$OMPPLACE" >> /tmp/omp.$$
done

NR=0
for ENTRY in `cat /tmp/omp.$$ | sort -n | uniq`; do
	if [ $NR -eq 6 ]; then
		echo
		NR=0
	fi
	echo -n "{$ENTRY}, "
	NR=$((NR+1))
done

rm /tmp/omp.$$
