function discover_script()
{
	local _discovered
	local _i
	local _t

	_discovered=$SCRIPTDIR/monitors/watch-$1
	for _i in "" .pl .sh
	do
		_t=${_discovered}${_i}
		if [ -e ${_t} ]
		then
			DISCOVERED_SCRIPT=${_t}
			return
		fi
	done
	echo "unable to discover script for ${_discovered}"
}

function start_monitor
{
	local _type _monitor

	_type=$1
	_monitor=$2

	export MONITOR_LOG=${MONITOR_DIR}/${_monitor}-${CURRENT_TEST}
	discover_script ${_monitor}
	start_${_type}_monitor $_monitor
	echo `date +%s` > ${MONITOR_LOG}.start
	cat /proc/uptime >> ${MONITOR_LOG}.start
}

function shutdown_monitors()
{
	local _pidfile _pid
	_pidfile=$1

	sync
	sleep 5
	for _pid in `cat ${_pidfile}`; do
		local _shutdown_signal=INT
		local _attempt=0
		if [ "`ps h --pid $_pid`" != "" ]; then
			echo -n "Shutting down monitor: $_pid"
			kill $_pid

			while [ "`ps h --pid $_pid`" != "" -a $_attempt -le 60 ]; do
				echo -n .
				sleep 1
				_attempt=$((_attempt+1))
				if [ $_attempt -ge 10 ]; then
					echo -n o
					kill -$_shutdown_signal $_pid
				fi
				if [ $_attempt -ge 20 ]; then
					_shutdown_signal=KILL
					echo -n O
					kill -$_shutdown_signal $_pid
				fi
				if [ $_attempt -ge 60 ]; then
					echo -n X
				fi
			done
			echo
		fi
		if [ -e $MONITOR_DIR/monitor.$_pid.compress ]; then
			LOG_COMPRESS=`cat $MONITOR_DIR/monitor.$_pid.compress`
			rm -f $MONITOR_DIR/monitor.$_pid.compress
			gzip -f $LOG_COMPRESS
		fi
	done

	rm $_pidfile
}

function start_always_monitor()
{
	local _monitor
	_monitor=$1
	_pidfile=$MONITOR_DIR/monitor.pids

	$EXPECT_UNBUFFER $DISCOVERED_SCRIPT > $MONITOR_LOG &
	echo $! >> $_pidfile
	echo "Started monitor ${_monitor} always pid `tail -1 $_pidfile`"
}

function start_gzip_monitor()
{
	local _monitor
	local _pidfile

	_monitor=$1
	_pidfile=$MONITOR_DIR/monitor.pids

	$EXPECT_UNBUFFER $DISCOVERED_SCRIPT 2>/dev/null > ${MONITOR_LOG} &
	PID1=$!
	echo $PID1 >> $_pidfile
	echo ${MONITOR_LOG} > $MONITOR_DIR/monitor.$PID1.compress

	PID1=`tail -1 $_pidfile`
	echo "Started monitor ${_monitor} gzip pid $PID1"
}

function start_with_latency_monitor()
{
	local _monitor
	local _pidfile

	_monitor=$1
	_pidfile=$MONITOR_DIR/monitor.pids

	rm -f /tmp/monitor-{1,2}.$$.pid
	($EXPECT_UNBUFFER $DISCOVERED_SCRIPT 2>/dev/null & echo $! > /tmp/monitor-1.$$.pid ) | \
		$SCRIPTDIR/monitors/latency-output /tmp/monitor-2.$$.pid > ${MONITOR_LOG} &

	wait_on_pid_file_create /tmp/monitor-1.$$.pid 10
	PID1=`cat /tmp/monitor-1.$$.pid`
	rm -f /tmp/monitor-1.$$.pid
	echo ${MONITOR_LOG} > $MONITOR_DIR/monitor.$PID1.compress

	wait_on_pid_file_create /tmp/monitor-2.$$.pid 10
	PID2=`cat /tmp/monitor-2.$$.pid 2> /dev/null`
	rm -f /tmp/monitor-2.$$.pid

	echo $PID2 >> $_pidfile
	echo $PID1 >> $_pidfile
	echo "Started monitor ${_monitor} latency pid $PID2,$PID1"
}

function start_tracer_monitor()
{
	export MONITOR_PID=${MONITOR_LOG}.pid

	local _monitor
	local _pidfile

	_monitor=$1
	_pidfile=$MONITOR_DIR/monitor.pids

	$EXPECT_UNBUFFER $DISCOVERED_SCRIPT &

	ATTEMPT=1
	while [ ! -e $MONITOR_PID ]; do
		sleep 1
		ATTEMPT=$((ATTEMPT+1))
		if [ $ATTEMPT -gt 10 ]; then
			die "Waited 10 seconds for ${_monitor} to start but no sign of it."
		fi
	done

	PID1=`cat $MONITOR_PID`
	rm $MONITOR_PID
	echo $PID1 >> $_pidfile
	echo "Started monitor ${_monitor} tracer pid $PID1"
}

function start_monitors() {
	local _start _type _monitors _monitor _wait_time

	export MONITOR_DIR=$SHELLPACK_LOG
	mkdir -p $MONITOR_DIR
	export GLOBAL_MONITOR_DIR=$MONITOR_DIR

	_wait_time=${MONITOR_WAIT_TIME:-0}
	if [ $_wait_time -gt 0 ]; then
		echo Sleeping $_wait_time seconds before starting monitors
		sleep $_wait_time
	fi

	for _type in always plain gzip with_latency tracer
	do
		_monitors=$(eval echo \$MONITORS_$(echo $_type | tr '[:lower:]' '[:upper:]'))
		for _monitor in $_monitors; do
			start_monitor $_type $_monitor
		done
	done

	if [ "$MONITOR_STAP" != "" ]; then
		echo Sleeping 30 seconds to give stap monitors change to load
		sleep 30
	fi
}

function stop_monitors() {
	[ -f ${GLOBAL_MONITOR_DIR}/monitor.pids ] && \
		shutdown_monitors ${GLOBAL_MONITOR_DIR}/monitor.pids
}

function check_monitor_stap() {
	local mon
	local chk

	for mon in $MONITORS_ALWAYS $MONITORS_GZIP $MONITORS_WITH_LATENCY $MONITORS_TRACER; do
		for chk in $MONITORS_STAP; do
			if [ "$mon" = "$chk" ]; then
				STAP_USED=monitor-$MONITOR
				MONITOR_STAP=monitor-$MONITOR
			fi
		done
	done
}
