#!/bin/bash
install-depends cpufrequtils
exec turbostat -i $MONITOR_UPDATE_FREQUENCY
