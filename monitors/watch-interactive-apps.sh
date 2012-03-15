#!/bin/bash

if [ "$MONITOR_INTERACTIVE_APPS" = "" ]; then
	MONITOR_INTERACTIVE_APPS="evolution akregator gnome-terminal xchat firefox konqueror mutt vi"
fi
if [ "$MONITOR_INTERACTIVE_APPS_STACKIGNORE" = "" ]; then
	MONITOR_INTERACTIVE_APPS_STACKIGNORE="poll_schedule_timeout do_wait fget_light inotify_poll sys_poll do_signal_stop"
fi
SEARCH_STACKIGNORE=`echo $MONITOR_INTERACTIVE_APPS_STACKIGNORE | sed -e 's/ /|/g'`

PIDS=$$
refresh_pids() {
	PIDS=$$
	for NAME in $MONITOR_INTERACTIVE_APPS; do
		PIDS="$PIDS `ps aux | grep " $NAME " | grep -v grep | awk '{print $2}'`"
	done
}


CURRENT_TIME=`date +%s`
SLEEP_INTERVAL=0.2
NEXT_DATE_REFRESH=5
NEXT_DATE_UPDATE=0
NEXT_REFRESH=0

while [ 1 ]; do
	if [ $NEXT_DATE_UPDATE -eq $NEXT_DATE_REFRESH ]; then
		CURRENT_TIME=`date +%s`
		NEXT_DATE_UPDATE=0
	fi
	NEXT_DATE_UPDATE=$((NEXT_DATE_UPDATE+1))
	for PID in $PIDS; do
		if [ ! -e /proc/$PID/stack -o $CURRENT_TIME -gt $NEXT_REFRESH ]; then
			refresh_pids
			NEXT_REFRESH=$((CURRENT_TIME+3))
			continue
		fi

		cat /proc/$PID/stack > /tmp/watch-$$-interactive.txt
		SEEN=`egrep "$SEARCH_STACKIGNORE" /tmp/watch-$$-interactive.txt | wc -l`
		if [ $SEEN -eq 0 ]; then
			head -1 /tmp/watch-$$-interactive.txt | grep -q 0x
			if [ $? -eq 0 ]; then
				echo time: $CURRENT_TIME
				echo proc: `ps --no-header -p $PID`
				cat /tmp/watch-$$-interactive.txt
			fi
		fi
	done
	sleep $SLEEP_INTERVAL
done

rm -f /tmp/watch-$$-interactive.txt
