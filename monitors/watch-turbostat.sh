#!/bin/bash
install-depends cpufrequtils
modprobe msr
exec turbostat -i $MONITOR_UPDATE_FREQUENCY
