#!/bin/bash
stap -v -v -g $SHELLPACK_STAP/periodic-alloc-atomic.stp &
STAPPID=$!
ATTEMPT=0

while [ $ATTEMPT -lt 5 ]; do
	sleep 5
	THISPID=`ps aux | grep stap | grep periodic-alloc-atomic | awk '{print $2}'`
	if [ "$THISPID" = "" ]; then
		echo Not running yet
		continue
	fi
		
	if [ "$STAPPID" = "$THISPID" ]; then
		ATTEMPT=$((ATTEMPT+1))
	else
		ATTEMPT=0
		STAPPID=$THISPID
	fi
done
echo Real pid: $STAPPID
echo $STAPPID >> monitor.pids
