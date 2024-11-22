#!/bin/bash
# BinDepend: iostat:sysstat
install-depends sysstat
exec iostat -xz $MONITOR_UPDATE_FREQUENCY
