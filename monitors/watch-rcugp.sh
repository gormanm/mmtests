#!/bin/bash
cd /sys/kernel/debug/rcu
if [ $? -ne 0 ]; then
	echo Kernel does not have CONFIG_RCU_TRACE and CONFIG_TREE_RCU_TRACE set
	exit -1
fi

RCU_FLAVOURS=`find -maxdepth 1 -type d | grep -v '^.$' | sed 's/..//'`
while [ 1 ]; do
	echo time: `date +%s`
	for RCU_FLAVOUR in $RCU_FLAVOURS; do
		echo -n "$RCU_FLAVOUR "
		cat $RCU_FLAVOUR/rcugp
	done
	sleep $MONITOR_UPDATE_FREQUENCY
done
