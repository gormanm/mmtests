#!/bin/bash
# BinDepend: iostat:sysstat
install-depends sysstat
exec iostat -x $MONITOR_UPDATE_FREQUENCY
