#!/bin/bash

if [ -e /proc/sys/kernel/sched_schedstats ]; then
	echo 1 > /proc/sys/kernel/sched_schedstats
fi

# Run perf sched system-wide 
exec perf sched record -o $MONITOR_LOG \
	perl -e "open(OUTPUT, \">$MONITOR_PID\"); print OUTPUT \$\$; close OUTPUT; sleep;"
