#!/bin/bash
# Select NAS class based on machine characteristics. Preference is for
# class D.

MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
MEMTOTAL_GB=$((MEMTOTAL_BYTES/1048576/1024))
NUMCPUS=`ls -d /sys/devices/system/cpu/cpu[0-9]* | wc -l`

# Class C needs at least 0.8GB so force B class for small machines
if [ $MEMTOTAL_GB -lt 2 ]; then
	echo B
	exit 0
fi

# Class D needs at least 12.8GB so force C class for small machines
if [ $MEMTOTAL_GB -lt 16 ]; then
	echo C
	exit 0
fi

# Require at least 16 CPUs to complete is a reasonable time
if [ $NUMCPUS -lt 16 ]; then
	echo C
	exit 0
fi

echo D
