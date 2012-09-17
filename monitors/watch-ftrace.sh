#!/bin/bash

if [ ! -e /sys/kernel/debug/tracing/ ]; then
	mount -t debugfs none /sys/kernel/debug 2>&1 || exit -1
fi

for EVENT in $MONITOR_FTRACE_EVENTS; do
	echo 1 > /sys/kernel/debug/tracing/events/$EVENT/enable 2>&1 || exit -1
done

exec cat /sys/kernel/debug/tracing/trace_pipe
