#!/bin/bash

if [ "$MONITOR_INTERACTIVE_APPS" = "" ]; then
	MONITOR_INTERACTIVE_APPS="evolution akregator gnome-terminal xchat firefox konqueror"
fi
if [ "$MONITOR_INTERACTIVE_APPS_STACKIGNORE" = "" ]; then
	MONITOR_INTERACTIVE_APPS_STACKIGNORE="poll_schedule_timeout do_wait"
fi

PIDS=$$
refresh_pids() {
	PIDS=$$
	for NAME in $MONITOR_INTERACTIVE_APPS; do
		PIDS="$PIDS `ps aux | grep $NAME | grep -v grep | awk '{print $2}'`"
	done
}

NEXT_REFRESH=0

while [ 1 ]; do
	CURRENT_TIME=`date +%s`
	for PID in $PIDS; do
		if [ ! -e /proc/$PID/stack -o $CURRENT_TIME -gt $NEXT_REFRESH ]; then
			refresh_pids
			NEXT_REFRESH=$((CURRENT_TIME+3))
			continue
		fi

		SEEN=
		COUNT=
		cat /proc/$PID/stack > /tmp/watch-$$-interactive.txt
		for OMIT in $MONITOR_INTERACTIVE_APPS_STACKIGNORE; do
			grep -q $OMIT /tmp/watch-$$-interactive.txt
			if [ $? -ne 0 ]; then
				SEEN=$((SEEN+1))
			fi
			COUNT=$((COUNT+1))
		done
		if [ $COUNT -eq $SEEN ]; then
			echo time: $CURRENT_TIME
			echo proc: `ps --no-header -p $PID`
			cat /tmp/watch-$$-interactive.txt
		fi
	done
	rm -f /tmp/watch-$$-interactive.txt
	sleep 0.2
done
