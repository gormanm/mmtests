#!/bin/bash

if [ "${STORAGE_CACHING_DEVICE}" = "" -o \
    "${STORAGE_BACKING_DEVICE}" = "" ]; then
	echo "ERROR: no caching and/or backing device specified"
	exit 1
fi

if [ "${STORAGE_CACHE_TYPE}" = "dm-cache" ]; then
	statuscmd="./bin/dmcache-setup.sh"
elif [ "${STORAGE_CACHE_TYPE}" = "bcache" ]; then
	statuscmd="./bin/bcache-setup.sh"
else
	echo "ERROR: invalid storage cache type (neither dm-cache nor bcache)"
	exit 1
fi

while [ 1 ]; do
	echo time: `date +%s`
	${statuscmd} -c ${STORAGE_CACHING_DEVICE} \
	    -b ${STORAGE_BACKING_DEVICE} --status
	sleep $MONITOR_UPDATE_FREQUENCY
done
