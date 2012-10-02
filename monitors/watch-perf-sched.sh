#!/bin/bash

# Run perf sched system-wide 
exec perf sched record -o $MONITOR_LOG \
	perl -e "open(OUTPUT, \">$MONITOR_PID\"); print OUTPUT \$\$; close OUTPUT; sleep;"
