#!/bin/bash
export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`

# Read list of nodes
while read tmp NID tmp tmp tmp; do
	if [ "$NODES" = "" ]; then
		NODES="$NID"
	else
		NODES="$NODES $NID"
	fi
done <<< "$(numactl --hardware | grep "size:")"

for NODE in $NODES; do
	declare -a SEEN
	SOCKET=0
	CPUS=`numactl --hardware | grep "node $NODE cpus:" | awk -F : '{print $2}' | sed -e 's/^\s*//'`
	for CPU in $CPUS; do
		if [ "${SEEN[$CPU]}" != "yes" ]; then
			CORE=0
			for CORE_SIBLING in $CPU `$SCRIPTDIR/list-cpu-siblings.pl $CPU node_cores $NODE | sed -e 's/,/ /g'`; do
				THREAD=0
				if [ "${SEEN[$CORE_SIBLING]}" != "yes" ]; then
					LLC=`cat /sys/devices/system/cpu/cpu$CORE_SIBLING/cache/index*/shared_cpu_list | tail -1`
					echo node $NODE socket $SOCKET core $CORE thread $THREAD cpu $CORE_SIBLING llc $LLC
					SEEN[$CORE_SIBLING]=yes
				fi

				for THREAD_SIBLING in `$SCRIPTDIR/list-cpu-siblings.pl $CORE_SIBLING threads $NODE | sed -e 's/,/ /g'`; do
					if [ "${SEEN[$THREAD_SIBLING]}" != "yes" ]; then
						THREAD=$((THREAD+1))
						LLC=`cat /sys/devices/system/cpu/cpu$THREAD_SIBLING/cache/index*/shared_cpu_list | tail -1`
						echo node $NODE socket $SOCKET core $CORE thread $THREAD cpu $THREAD_SIBLING llc $LLC
						SEEN[$THREAD_SIBLING]=yes
					fi
				done
				CORE=$((CORE+1))
			done
		fi
		SOCKET=$((SOCKET+1))
	done
done
