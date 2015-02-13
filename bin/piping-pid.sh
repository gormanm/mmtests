#!/bin/bash

PIPEE=$1
if [ "$PIPEE" = "" ]; then
	echo Specify a PID of a process being piped to
	exit -1
fi

PIPEID=`ls -l /proc/$PIPEE/fd/0 | awk '{print $NF}' | sed -e 's/\\[/\\\[/' -e 's/\\]/\\\]/'`
echo $PIPEID | grep -q pipe
if [ $? -ne 0 ]; then
	echo $PIPEE
	exit
fi
PIPER=`ls -lrt /proc/[0-9]*/fd/1 | grep $PIPEID | awk '{print $(NF-2)}' | awk -F / '{print $3}'`
echo $PIPER
