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

# support for deferred monitors
function is_deferred_monitor()
{
	local _tmp

	for i in $DEFERRED_MONITORS
	do
		[ $i == "$1" -o "$i" == "all" ] && return 0
	done

	return 1
}

function add_deferred_monitor()
{
	local _monitor _type

	_type=$1
	_monitor=$2

	export MONITORS_TO_DEFER="$MONITORS_TO_DEFER $_monitor:$_type"
}

function create_monitor_dir()
{
	local _deferred
	local OPTIND
	local _o
	local _tagdesc

	_deferred=0
	_tagdesc=""
	while getopts ":t:d" _o
	do
		case $_o in
		t) _tagdesc=$OPTARG;;
		d) _deferred=1;;
		esac
	done
	shift $((OPTIND-1))

	if [ $_deferred -eq 1 ]
	then
		if [ -z "$DEFERRED_MONITOR_INDEX" ]
		then
			export DEFERRED_MONITOR_INDEX=1
		else
			export DEFERRED_MONITOR_INDEX=$((DEFERRED_MONITOR_INDEX+1))
		fi
		export MONITOR_DIR=$SHELLPACK_LOG/deferred_monitors.${DEFERRED_MONITOR_INDEX}
	else
		export MONITOR_DIR=$SHELLPACK_LOG
	fi

	[ -d $MONITOR_DIR ] || mkdir $MONITOR_DIR

	[ -n "$_tagdesc" ] && echo "$_tagdesc" > ${MONITOR_DIR}/description
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

function start_deferred_monitor()
{
	local _monitor _type

	case $1 in
		*:*) IFS=:
		     set -- $1
		     _monitor=$1
		     _type=$2
		     start_monitor $_type $_monitor
		     unset IFS
		     ;;
		*) return
	esac
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

			while [ "`ps h --pid $_pid`" != "" ]; do
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
			done
			echo
		fi
	done

	rm $_pidfile
}

function stop_deferred_monitors()
{
	[ -n "$MONITORS_TO_DEFER" ] && shutdown_monitors $MONITOR_DIR/monitor.pids
}

function start_deferred_monitors()
{
	local _monitor
	local _arg

	if [ "$MONITORS_TO_DEFER" = "" ]; then
		return
	fi

	if [ -n "$1" ]
	then
		create_monitor_dir -d -t "$1"
	else
		create_monitor_dir -d
	fi

	for _monitor in $MONITORS_TO_DEFER
	do
		start_deferred_monitor $_monitor
	done
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

	($EXPECT_UNBUFFER $DISCOVERED_SCRIPT & echo $! >> $_pidfile ) | gzip -c > ${MONITOR_LOG}.gz &
	PID1=`tail -1 $_pidfile`
	echo "Started monitor ${_monitor} gzip pid $PID1"
}

function start_with_latency_monitor()
{
	local _monitor
	local _pidfile

	_monitor=$1
	_pidfile=$MONITOR_DIR/monitor.pids

	( $EXPECT_UNBUFFER $DISCOVERED_SCRIPT & echo -n $! > /tmp/monitor-1.$$.pid ) | \
		( $SCRIPTDIR/monitors/latency-output & echo -n $! > /tmp/monitor-2.$$.pid ) | gzip -c > ${MONITOR_LOG}.gz &
	PID1=`cat /tmp/monitor-1.$$.pid`
	rm -f /tmp/monitor-1.$$.pid
	PID2=`cat /tmp/monitor-2.$$.pid`
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
	local _start _type _monitors _monitor

	create_monitor_dir
	export GLOBAL_MONITOR_DIR=$MONITOR_DIR

	for _type in always plain gzip with_latency tracer
	do
		_monitors=$(eval echo \$MONITORS_$(echo $_type | tr '[:lower:]' '[:upper:]'))
		for _monitor in $_monitors; do
			if is_deferred_monitor $_monitor
			then
				add_deferred_monitor $_type $_monitor
			else
				start_monitor $_type $_monitor
			fi
		done
	done

	if [ "$MONITOR_STAP" != "" ]; then
		echo Sleeping 30 seconds to give stap monitors change to load
		sleep 30
	fi
}

function stop_monitors() {
	# If all monitors are deferred, there will be no global monitor.pids

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
