#!/bin/bash

# Guess what partition we are running from. Awful but could not
# be arsed figuring out what device we are running on based
# in the output of stat and this happens to work on all my
# test machines
if [ "$TESTDISK_PARTITION" = "" ]; then
	ROOT_DEV=`mount | grep " / " | awk '{print $1}'`
	ROOT_DRIVE=`echo $ROOT_MOUNT | sed -e 's/[0-9]//'`
	if [ -e $ROOT_DRIVE ]; then
		TESTDISK_PARTITION=$ROOT_DRIVE
	else
		TESTDISK_PARTITION=$ROOT_DEV
	fi
fi

cd `dirname $MONITOR_LOG` || exit
exec blktrace -d $TESTDISK_PARTITION -o `basename $MONITOR_LOG`
