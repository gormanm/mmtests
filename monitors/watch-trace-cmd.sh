#!/bin/bash

if [ ! -e /sys/kernel/debug/tracing/ ]; then
	mount -t debugfs none /sys/kernel/debug 2>&1 || exit -1
fi

install-depends trace-cmd

TRACE_EVENTS=

for EVENT in $MONITOR_FTRACE_EVENTS; do
	TRACE_EVENTS="$TRACE_EVENTS -e $EVENT"
done

exec trace-cmd record $TRACE_EVENTS -o $MONITOR_LOG-trace.dat
