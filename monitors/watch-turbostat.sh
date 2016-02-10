#!/bin/bash
install-depends cpufrequtils
install-depends cpupower
modprobe msr
exec turbostat -i $MONITOR_UPDATE_FREQUENCY
