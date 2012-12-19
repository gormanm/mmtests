#!/bin/bash
install-depends sysstat
exec iostat -x $MONITOR_UPDATE_FREQUENCY
