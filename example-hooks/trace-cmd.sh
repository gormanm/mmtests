# Run trace-cmd for each subtest.  To use it, source this file or copy
#  the functions to your config file and add the export below:
#  export MONITOR_HOOKS="trace-cmd"
# and define trace-events with
#  export MONITOR_FTRACE_EVENTS="<events>"

trace-cmd_monitor-init() {
	zypper install -y trace-cmd
}

trace-cmd_monitor-pre () {
	local logdir=$1
	local subtest=$2

	TRACE_EVENTS=
	for EVENT in $MONITOR_FTRACE_EVENTS; do
		TRACE_EVENTS+=" -e $EVENT"
	done

	trace-cmd record -a $TRACE_EVENTS -o $logdir/trace-cmd-$subtest.data &
	echo $! > $logdir/trace-cmd.pid
	echo -n Waiting on ftrace to start
	while [ ! -e $logdir/trace-cmd-$subtest.data.cpu0 ]; do
		echo -n .
		sleep 1
	done

}
trace-cmd_monitor-post() {
	local logdir=$1
	local subtest=$2

	# terminate trace-cmd
	TRACE_PID=$(cat $logdir/trace-cmd.pid)
	kill -s 2 $TRACE_PID
	sleep 1
	while [ "`ps h --pid $TRACE_PID`" != "" ]; do
		echo -n .
		sleep 1
	done
	echo trace-cmd exited: $(date)
	rm $logdir/trace-cmd.pid
	sleep 1
}

trace-cmd-record_monitor-end() {
	for name in $(find work/log/$RUNNAME -name "trace-cmd*") ; do
		gzip $name
	done
}
