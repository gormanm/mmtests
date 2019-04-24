#!/bin/bash

CPUIDLE_ROOT=/sys/devices/system/cpu/cpu0/cpuidle
for STATE in `\ls $CPUIDLE_ROOT | sed -e 's/state//' | sort -n`; do
	printf "%-4s %5s %4d\n" c-$STATE `cat $CPUIDLE_ROOT/state${STATE}/name` `cat $CPUIDLE_ROOT/state${STATE}/latency`
done
	

