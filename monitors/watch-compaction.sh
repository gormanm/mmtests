#!/bin/bash

# monitors mm compaction times using perf script

term_handler()
{
if [ -n "$perf_child" ]
then
	kill -SIGINT $perf_child
fi
}

PERF_DATA=`mktemp`

trap "term_handler" SIGTERM
trap "rm -f $PERF_DATA" EXIT

# Run perf sched system-wide
perf script record compaction-times -q -o $PERF_DATA &
pid=$!
while [ -z "$perf_child" ]
do
	perf_child=`ps --ppid $pid -o pid -h`
done
wc=-1
while [ "$wc" -ne 0 ]
do
	wait
	wc=$?
done
perf script report compaction-times -i $PERF_DATA -- $MONITOR_COMPACTION_OPTS
