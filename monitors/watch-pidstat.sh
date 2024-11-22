#!/bin/bash
# BinDepend: pidstat:sysstat
exec pidstat -H -h -u -d -r $MONITOR_UPDATE_FREQUENCY
