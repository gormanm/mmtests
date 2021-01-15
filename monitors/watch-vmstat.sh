#!/bin/bash
# BinDepend: vmstat:procps
exec vmstat -n $MONITOR_UPDATE_FREQUENCY
