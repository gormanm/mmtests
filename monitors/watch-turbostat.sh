#!/bin/bash
install-depends cpufrequtils
install-depends cpupower
modprobe msr

EXTRA_PARAM=
MAJOR_VERSION=`turbostat --version 2>&1 | awk '{print $3}' | awk -F . '{print $1}'`
if [ $MAJOR_VERSION -ge 2026 ]; then
	EXTRA_PARAM="--no-perf"
fi

exec turbostat $EXTRA_PARAM -i $MONITOR_UPDATE_FREQUENCY
