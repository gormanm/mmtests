#!/bin/bash
DEFAULT_CONFIG=config
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME" && pwd`
export PATH="$SCRIPTDIR/bin:$PATH"
RUNNING_TEST=
KVM=
export EXPECT_UNBUFFER=$SCRIPTDIR/bin/unbuffer

INTERRUPT_COUNT=0
begin_shutdown() {
	INTERRUPT_COUNT=$((INTERRUPT_COUNT+1))
	TEST_PID=
	if [ "$RUNNING_TEST" != "" ]; then
		echo Interrupt received, shutting down $RUNNING_TEST
		ps auxwww | grep shellpack-bench-$RUNNING_TEST | grep -v grep
		TEST_PID=`ps auxwww | grep shellpack-bench-$RUNNING_TEST | grep -v grep | awk '{print $2}'`
		if [ "$TEST_PID" = "" ]; then
			TEST_PID=`ps auxwww | grep shellpack-install-$RUNNING_TEST | grep -v grep | awk '{print $2}'`
		fi
	fi
	if [ "$TEST_PID" != "" ]; then
		echo Sending shutdown request to running test pid $TEST_PID
		/bin/kill $TEST_PID

		if [ $INTERRUPT_COUNT -gt 3 ]; then
			echo Fine, force killing running test
			/bin/kill -9 $TEST_PID
		fi
	else
		echo Interrupt received but test not running to shutdown
	fi

	if [ $INTERRUPT_COUNT -gt 10 ]; then
		echo OK, bailing without any attempt at cleanup
		exit -1
	fi

}
trap begin_shutdown SIGTERM
trap begin_shutdown SIGINT

usage() {
	echo "$0 [-mn] [-c path_to_config] runname"
	echo
	echo "-k|--kvm         Run inside KVM instance"
	echo "-m|--run-monitor Force enable monitor."
	echo "-n|--no-monitor  Force disable monitor."
	echo "-c|--config      Use MMTests config, default is ./config, more than one can be specified"
	echo "-h|--help        Prints this help."
}

# Parse command-line arguments
ARGS=`getopt -o kmnc:h --long kvm,help,run-monitor,no-monitor,config: -n run-mmtests -- "$@"`
KVM_ARGS=
declare -a CONFIGS
export CONFIGS
eval set -- "$ARGS"
while true; do
	case "$1" in
		-k|--kvm)
			export KVM=yes
			shift
			;;
		-m|--run-monitor)
			export FORCE_RUN_MONITOR=yes
			KVM_ARGS="$KVM_ARGS $1"
			shift
			;;
		-n|--no-monitor)
			export FORCE_RUN_MONITOR=no
			KVM_ARGS="$KVM_ARGS $1"
			shift
			;;
		-c|--config)
			DEFAULT_CONFIG=
			CONFIGS+=( "$2" )
			KVM_ARGS="$KVM_ARGS $1 $2"
			shift 2
			;;
		-h|--help)
			usage
			KVM_ARGS="$KVM_ARGS $1"
			exit $SHELLPACK_SUCCESS
			;;
		--)
			break
			;;
		*)
			echo ERROR: Unrecognised option $1
			usage
			exit $SHELLPACK_ERROR
			;;
	esac
done

if ! [ -z $DEFAULT_CONFIG ]; then
	CONFIGS=( "$DEFAULT_CONFIG" )
fi

# Take the unparsed option as the parameter
shift
export RUNNAME=$1

if [ -z "$RUNNAME" ]; then
	echo "ERROR: Runname parameter must be specified"
	usage
	exit -1
fi

# Import configs
for ((i = 0; i < ${#CONFIGS[@]}; i++ )); do
	if [ ! -e "${CONFIGS[$i]}" ]; then
		echo "A config must be in the current directory or specified with --config"
		echo "File ${CONFIGS[$i]} not found"
		exit -1
	fi
done

rm -f $SCRIPTDIR/bash_arrays # remove stale bash_arrays file
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/shellpacks/deferred-monitors.sh

for ((i = 0; i < ${#CONFIGS[@]}; i++ )); do
	source "${CONFIGS[$i]}"
done

# Create directories that must exist
cd $SHELLPACK_TOPLEVEL

setup_dirs

# Mount the log directory on the requested partition if requested
if [ "$LOGDISK_PARTITION" != "" ]; then
	echo Unmounting log partition: $SHELLPACK_LOG_BASE
	umount $SHELLPACK_LOG_BASE

	echo $LOGDISK_PARTITION | grep \/ram
	if [ $? -eq 0 ]; then
		modprobe brd
	fi

	if [ "$LOGDISK_FILESYSTEM" != "" -a "$LOGDISK_FILESYSTEM" != "tmpfs" ]; then
		echo Formatting log disk: $LOGDISK_FILESYSTEM
		mkfs.$LOGDISK_FILESYSTEM $LOGDISK_MKFS_PARAM $LOGDISK_PARTITION
		if [ $? -ne 0 ]; then
			echo Forcing creating of filesystem if possible
			mkfs.$LOGDISK_FILESYSTEM -F $LOGDISK_MKFS_PARAM $LOGDISK_PARTITION || exit
		fi
	fi

	echo Mounting log disk
	if [ "$LOGDISK_MOUNT_ARGS" = "" ]; then
		mount -t $LOGDISK_FILESYSTEM $LOGDISK_PARTITION $SHELLPACK_LOG_BASE || exit
	else
		mount -t $LOGDISK_FILESYSTEM $LOGDISK_PARTITION $SHELLPACK_LOG_BASE -o $LOGDISK_MOUNT_ARGS || exit
	fi
fi

# Run inside KVM if requested
if [ "$KVM" = "yes" ]; then
	echo Launching KVM
	$SHELLPACK_TOPLEVEL/run-kvm.sh
	if [ $? -ne 0 ]; then
		echo KVM failed to start properly
		exit -1
	fi
	reset
	cd $SHELLPACK_TOPLEVEL

	RCMD="ssh -p 30022 root@localhost"

	echo Executing mmtest inside KVM: run-mmtests.sh $KVM_ARGS $RUNNAME
	echo MMtests toplevel: $SHELLPACK_TOPLEVEL
	echo MMTests logs: $SHELLPACK_LOG_BASE
	$RCMD "cd $SHELLPACK_TOPLEVEL && ./run-mmtests.sh $KVM_ARGS $RUNNAME"
	RETVAL=$?
	echo Copying KVM logs
	scp -r -P 30022 "root@localhost:$SHELLPACK_LOG_BASE/*" "$SHELLPACK_LOG_BASE/"
	scp -r -P 30022 "root@localhost:$SHELLPACK_TOPLEVEL/kvm-console.log" "$SHELLPACK_LOG/kvm-console.log"

	echo Shutting down KVM
	$RCMD shutdown -h now
	sleep 30
	kill -9 `cat qemu.pid`
	rm -f qemu.pid
	exit $RETVAL
fi

# Force artificial date is requested
if [ "$MMTESTS_FORCE_DATE" != "" ]; then
	killall -STOP ntpd
	MMTESTS_FORCE_DATE_BASE=`date +%s`
	date -s "$MMTESTS_FORCE_DATE"
	MMTESTS_FORCE_DATE_START=`date +%s`
	echo Forcing reset of date: `date`
fi

# Install packages that are generally needed by a large number of tests
install-depends autoconf automake binutils-devel bzip2 dosfstools expect
install-depends expect-devel gcc gcc-32bit libhugetlbfs libtool make oprofile patch
install-depends recode systemtap xfsprogs xfsprogs-devel psmisc btrfsprogs xz wget
install-depends perl-Time-HiRes time tcl
install-depends kpartx util-linux
install-depends hwloc-lstopo numactl
install-depends cpupower
install-depends util-linux

# Check monitoring
if [ "$FORCE_RUN_MONITOR" != "" ]; then
	RUN_MONITOR=$FORCE_RUN_MONITOR
fi
if [ "$RUN_MONITOR" = "no" ]; then
	# Disable monitor
	unset MONITORS_PLAIN
	unset MONITORS_GZIP
	unset MONITORS_WITH_LATENCY
	unset MONITORS_TRACER
else
	# Check at least one monitor is enabled
	if [ "$MONITORS_ALWAYS" = "" -a "$MONITORS_PLAIN" = "" -a "$MONITORS_GZIP" = "" -a "$MONITORS_WITH_LATENCY" = "" -a "$MONITORS_TRACER" = "" ]; then
		echo WARNING: Monitors enabled but none configured
	fi
fi

# Validate systemtap installation if it exists
TESTS_STAP="highalloc pagealloc highalloc"
MONITORS_STAP="dstate stap-highorder-atomic function-frequency syscalls"
STAP_USED=
MONITOR_STAP=
for TEST in $MMTESTS; do
	for CHECK in $TESTS_STAP; do
		if [ "$TEST" = "$CHECK" ]; then
			STAP_USED=test-$TEST
		fi
	done
done
for MONITOR in $MONITORS_ALWAYS $MONITORS_PLAIN $MONITORS_GZIP $MONITORS_WITH_LATENCY $MONITORS_TRACER; do
	for CHECK in $MONITORS_STAP; do
		if [ "$MONITOR" = "$CHECK" ]; then
			STAP_USED=monitor-$MONITOR
			MONITOR_STAP=monitor-$MONITOR
		fi
	done
done
if [ "$STAP_USED" != "" ]; then
	if [ "`which stap`" = "" ]; then
		echo ERROR: systemtap required for $STAP_USED but not installed
		exit -1
	fi

	stap-fix.sh
	if [ $? != 0 ]; then
		echo "ERROR: systemtap required for $STAP_USED but systemtap is broken and unable"
		echo "       to workaround with stap-fix.sh"
		if [ "`uname -m`" != "aarch64" ]; then
			exit $SHELLPACK_ERROR
		fi
	fi
fi

function start_monitors() {
	local _start _type _monitors _monitor

	create_monitor_dir
	GLOBAL_MONITOR_DIR=$MONITOR_DIR

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

# Run tunings
if [ "$RUN_TUNINGS" != "" ]; then
	echo Tuning the system before running: $RUNNAME
	for T in $RUN_TUNINGS; do
		discover_script ./tunings/tuning-$T
		export TUNING_LOG=$SHELLPACK_LOG/$T-$TEST
		$EXPECT_UNBUFFER $DISCOVERED_SCRIPT > $TUNING_LOG || exit $SHELLPACK_ERROR
	done
fi

# If profiling is enabled, make sure the necessary oprofile helpers are
# available and that there is a unable vmlinux file in the expected
# place
export EXPANDED_VMLINUX=no
if [ "$RUN_FINEPROFILE" = "yes" -o "$RUN_COARSEPROFILE" = "yes" ]; then
	VMLINUX=/boot/vmlinux-`uname -r`
	if [ ! -e $VMLINUX -a -e $VMLINUX.gz ]; then
		echo Expanding vmlinux.gz file
		gunzip $VMLINUX.gz || die "Failed to expand vmlinux file for profiling"
		export EXPANDED_VMLINUX=yes
	fi

	if [ "`cat /proc/sys/kernel/nmi_watchdog`" = "1" ]; then
		echo Disabling NMI watchdog for profiling
		echo 0 > /proc/sys/kernel/nmi_watchdog
	fi
fi

# Disable any inadvertent profiling going on right now
if [ "`lsmod | grep oprofile`" != "" ]; then
	opcontrol --stop > /dev/null 2> /dev/null
	opcontrol --deinit > /dev/null 2> /dev/null
fi

# Wait for ntp to stabilize system clock so that time skips don't confuse
# benchmarks (bsc#1066465)
if [ "`which ntp-wait`" != "" ]; then
	echo "Waiting for NTP to stabilize system clock..."
	ntp-wait -v -s 1 -n 600
	if [ $? -ne 0 ]; then
		echo "Failed to stabilize system clock!";
		systemctl stop ntpd.service
	fi
	systemctl stop ntpd.service
	systemctl stop chronyd.service
	systemctl stop time-sync.target
fi

if [ "$MMTESTS_NUMA_POLICY" = "numad" ]; then
	install-depends numad

	if [ `which numad 2>/dev/null` = "" ]; then
		die numad requested but unavailable
	fi
fi

MMTEST_ITERATIONS=${MMTEST_ITERATIONS:-1}
export SHELLPACK_LOG_RUNBASE=$SHELLPACK_LOG_BASE/$RUNNAME
export SHELLPACK_ACTIVITY="$SHELLPACK_LOG_RUNBASE/tests-activity"
# Delete old runs
rm -rf $SHELLPACK_LOG_RUNBASE &>/dev/null
mkdir -p $SHELLPACK_LOG_RUNBASE
echo `date +%s` run-mmtests: Start > $SHELLPACK_ACTIVITY

sysstate_log() {
	echo "$@" >> $SHELLPACK_SYSSTATEFILE
}

teststate_log() {
	sysstate_log "$@"
	echo "$@" >> $SHELLPACK_LOGFILE
}

for (( MMTEST_ITERATION = 0; MMTEST_ITERATION < $MMTEST_ITERATIONS; MMTEST_ITERATION++ )); do
	export SHELLPACK_LOG=$SHELLPACK_LOG_RUNBASE/iter-$MMTEST_ITERATION
	mkdir -p $SHELLPACK_LOG

	# Test interrupted? Abort iteration
	if [ "$INTERRUPT_COUNT" -gt 0 ]; then
		break
	fi
	create_testdisk

	# Create test disk(s)
	if [ "$TESTDISK_PARTITION" != "" ]; then
		# override any TESTDISK_PARTITIONS configuration (for backwards compatibility)
		TESTDISK_PARTITIONS=($TESTDISK_PARTITION)
	fi

	# Export variables needed for successful setup of filesystems
	export STORAGE_CACHE_TYPE STORAGE_CACHING_DEVICE STORAGE_BACKING_DEVICE
	export TESTDISK_PARTITIONS
	export TESTDISK_FILESYSTEM
	export TESTDISK_FS_SIZE
	export TESTDISK_MKFS_PARAM
	export TESTDISK_MOUNT_ARGS
	export TESTDISK_NFS_MOUNT
	export SHELLPACK_TEST_MOUNTS
	export SHELLPACK_DATA_DIRS

	setup_io_scheduler

	create_filesystems

	# Prepared environment in a directory, does not work together with
	# TESTDISK_PARTITION and co.
	if [ "$TESTDISK_DIR" != "" ]; then
		if [ "$SHELLPACK_TEST_MOUNT" != "" -a ${#TESTDISK_PARTITIONS[*]} -gt 0 ]; then
			die "Can't use TESTDISK_PARTITION(S) together with TESTDISK_DIR"
		fi
		if ! [ -d "$TESTDISK_DIR" ]; then
			die "Can't find TESTDISK_DIR $TESTDISK_DIR"
		fi
		echo "Using directory $TESTDISK_DIR for test"
		SHELLPACK_DATA=$TESTDISK_DIR
	else
		if [ ${#SHELLPACK_TEST_MOUNTS[*]} -gt 0 -a ${#TESTDISK_PARTITIONS[*]} -gt 0 ]; then
			for i in ${!SHELLPACK_TEST_MOUNTS[*]}; do
				if [ $i -eq 0 ]; then
					SHELLPACK_DATA_DIRS[$i]="$SHELLPACK_DATA"
				else
					SHELLPACK_DATA_DIRS[$i]="${SHELLPACK_TEST_MOUNTS[$i]}/data"
				fi
				echo "Using ${SHELLPACK_DATA_DIRS[$i]}"
			done
		else
			echo "Using default SHELLPACK_DATA"
			# In case no special data storage is defined, we default to
			# SHELLPACK_TEMP which gets automatically cleaned up
			SHELLPACK_DATA="$SHELLPACK_TEMP"
		fi
	fi

	if [ "$SWAP_CONFIGURATION" = "" ]; then
		export SWAP_CONFIGURATION=default
	fi

	# Configure swap
	case $SWAP_CONFIGURATION in
	partitions)
		echo Disabling existing swap
		swapoff -a
		for SWAP_PART in $SWAP_PARTITIONS; do
			echo Enabling swap on partition $SWAP_PART
			swapon $SWAP_PART
			if [ $? -ne 0 ]; then
				mkswap $SWAP_PART || die Failed to mkswap $SWAP_PART
				swapon $SWAP_PART || die Failed to enable swap on $SWAP_PART
			fi
		done
		;;
	swapfile)
		echo Disabling existing swap
		swapoff -a

		CREATE_SWAP=no
		if [ -e $SHELLPACK_TEMP/swapfile ]; then
			EXISTING_SIZE=`stat $SHELLPACK_TEMP/swapfile | grep Size: | awk '{print $2}'`
			EXISTING_SIZE=$((EXISTING_SIZE/1048576))
			if [ $EXISTING_SIZE -ne $SWAP_SWAPFILE_SIZEMB ]; then
				CREATE_SWAP=yes
			fi
		else
			CREATE_SWAP=yes
		fi
		if [ "$CREATE_SWAP" = "yes" ]; then
			echo Creating local swapfile
			dd if=/dev/zero of=$SHELLPACK_TEMP/swapfile ibs=1048576 count=$SWAP_SWAPFILE_SIZEMB
			mkswap $SHELLPACK_TEMP/swapfile || die Failed to mkswap $SHELLPACK_TEMP/swapfile
		fi
		echo Activating swap
		swapon $SHELLPACK_TEMP/swapfile || die Failed to activate $SHELLPACK_TEMP/swapfile
		echo Activated swap
		;;
	NFS)
		if [ "$SWAP_NFS_MOUNT" = "" ]; then
			die "SWAP_NFS_MOUNT not specified in config"
		fi

		/etc/init.d/rpcbind start
		MNTPNT=$SHELLPACK_TOPLEVEL/work/nfs-swapfile
		mkdir -p $MNTPNT || die "Failed to create NFS mount for swap"
		mount $SWAP_NFS_MOUNT $MNTPNT || die "Failed to mount NFS mount for swap"

		echo Disabling existing swap
		swapoff -a

		CREATE_SWAP=no
		if [ -e $MNTPNT/swapfile ]; then
			EXISTING_SIZE=`stat $MNTPNT/swapfile | grep Size: | awk '{print $2}'`
			EXISTING_SIZE=$((EXISTING_SIZE/1048576))
			if [ $((EXISTING_SIZE/20)) -ne $((SWAP_SWAPFILE_SIZEMB/20)) ]; then
				echo Slightly annoying: $EXISTING_SIZE -ne $SWAP_SWAPFILE_SIZEMB
				CREATE_SWAP=yes
			fi
		else
			CREATE_SWAP=yes
		fi
		if [ "$CREATE_SWAP" = "yes" ]; then
			echo Creating nfs swapfile
			dd if=/dev/zero of=$MNTPNT/swapfile ibs=1048576 count=$SWAP_SWAPFILE_SIZEMB
			mkswap $MNTPNT/swapfile || die Failed to mkswap $MNTPNT/swapfile
		fi
		echo Activating swap
		swapon $MNTPNT/swapfile || die Failed to activate $MNTPNT/swapfile
		echo Activated swap
		;;
	nbd)
		modprobe nbd || exit
		nbd-client -d $SWAP_NBD_DEVICE
		echo Connecting NBD client $SWAP_NBD_HOST $SWAP_NBD_PORT $SWAP_NBD_DEVICE
		nbd-client $SWAP_NBD_HOST -swap $SWAP_NBD_PORT $SWAP_NBD_DEVICE || exit

		echo Disabling existing swap
		swapoff -a

		echo Formatting as swap
		mkswap $SWAP_NBD_DEVICE

		echo Activating swap
		swapon $SWAP_NBD_DEVICE || die Failed to activate NBD swap
		;;
	default)
		;;
	esac

	if [ "$SWAP_CONFIGURATION" != "default" ]; then
		echo Swap configuration
		swapon -s
	fi

	# Save bash arrays (marked as exported) to separate file. They are
	# read-in via common.sh in subshells. This quirk is req'd as bash
	# doesn't support export of arrays. Note that the file needs to be
	# updated whenever an array is modified after this point.
	# Currently required for:
	# - SHELLPACK_TEST_MOUNTS, TESTDISK_PARTITIONS, SHELLPACK_DATA_DIRS
	declare -p | grep "\-ax" > $SCRIPTDIR/bash_arrays

	# Warm up. More appropriate warmup depends on the exact test
	if [ "$RUN_WARMUP" != "" ]; then
		echo Entering warmup
		RUNNING_TEST=$RUN_WARMUP
		./bin/run-single-test.sh $RUN_WARMUP
		RUNNING_TEST=
		rm -rf $SHELLPACK_LOG/$RUN_WARMUP
		echo Warmup complete, beginning tests
	fi
		
	export SHELLPACK_LOGFILE="$SHELLPACK_LOG/tests-timestamp"
	export SHELLPACK_SYSSTATEFILE="$SHELLPACK_LOG/tests-sysstate"
	echo `date +%s` "run-mmtests: Iteration $MMTEST_ITERATION start" >> $SHELLPACK_ACTIVITY

	if [ "$MMTESTS_NUMA_POLICY" = "numad" ]; then
		echo Restart numad and purge log as per MMTESTS_NUMA_POLICY
		killall -KILL numad
		rm -f /var/log/numad.log
		numad -F -d &> $SHELLPACK_LOG/numad-stdout &
		export NUMAD_PID=$!
		echo -n Waiting on numad.log
		while [ ! -e /var/log/numad.log ]; do
			echo .
			sleep 1
		done
		echo
		echo Numad started: pid $NUMAD_PID
	fi

	# Create memory control group if requested
	if [ "$CGROUP_MEMORY_SIZE" != "" ]; then
		mkdir -p /sys/fs/cgroup/memory/0 || die "Failed to create memory cgroup"
		echo $CGROUP_MEMORY_SIZE > /sys/fs/cgroup/memory/0/memory.limit_in_bytes || die "Failed to set memory limit"
		echo $$ > /sys/fs/cgroup/memory/0/tasks
		echo Memory limit configured: `cat /sys/fs/cgroup/memory/0/memory.limit_in_bytes`
	fi

	if [ "$CGROUP_CPU_TAG" != "" ]; then
		mkdir -p /sys/fs/cgroup/cpu/0 || die "Failed to create cpu cgroup"
		echo $CGROUP_CPU_TAG > /sys/fs/cgroup/cpu/0/cpu.tag || die "Failed to create CPU sched tag"
		echo $$ > /sys/fs/cgroup/cpu/0/tasks
		echo CPU Tags set: `cat /sys/fs/cgroup/cpu/0/cpu.tag`
	fi

	EXIT_CODE=$SHELLPACK_SUCCESS

	# Run tests in single mode
	rm -f $SHELLPACK_LOGFILE $SHELLPACK_SYSSTATEFILE
	teststate_log "start :: `date +%s`"
	if [ "$RAID_CREATE_END" != "" ]; then
		teststate_log "raid-create :: $((RAID_CREATE_END-RAID_CREATE_START))"
	fi
	sysstate_log "arch :: `uname -m`"
	sysstate_log "`ip addr show`"
	sysstate_log "mount :: start"
	sysstate_log "`mount`"
	sysstate_log "/proc/mounts :: start"
	sysstate_log "`cat /proc/mounts`"
	if [ "`which numactl 2> /dev/null`" != "" ]; then
		numactl --hardware > $SHELLPACK_LOG/numactl.txt
		gzip $SHELLPACK_LOG/numactl.txt
	fi
	if [ "`which lscpu 2> /dev/null`" != "" ]; then
		lscpu > $SHELLPACK_LOG/lscpu.txt
		gzip $SHELLPACK_LOG/lscpu.txt
	fi
	if [ "`which cpupower 2> /dev/null`" != "" ]; then
		cpupower frequency-info > $SHELLPACK_LOG/cpupower.txt
		gzip $SHELLPACK_LOG/cpupower.txt
	fi
	if [ "`which lstopo 2> /dev/null`" != "" ]; then
		lstopo $SHELLPACK_LOG/lstopo.pdf 2>/dev/null
		lstopo --output-format txt > $SHELLPACK_LOG/lstopo.txt
		gzip $SHELLPACK_LOG/lstopo.pdf
		gzip $SHELLPACK_LOG/lstopo.txt
	fi
	if [ "`which lsscsi 2> /dev/null`" != "" ]; then
		lsscsi > $SHELLPACK_LOG/lsscsi.txt
		gzip $SHELLPACK_LOG/lsscsi.txt
	fi
	if [ "`which list-cpu-toplogy.sh 2> /dev/null`" != "" ]; then
		list-cpu-toplogy.sh > $SHELLPACK_LOG/cpu-topology-mmtests.txt
		gzip $SHELLPACK_LOG/cpu-topology-mmtests.txt
	fi
	if [ "`which set-cstate-latency.pl 2> /dev/null`" != "" ]; then
		set-cstate-latency.pl > $SHELLPACK_LOG/cstate-latencies-${RUNNAME}.txt
	fi
	if [ -e /sys/devices/system/cpu/vulnerabilities ]; then
		grep . /sys/devices/system/cpu/vulnerabilities/* > $SHELLPACK_LOG/cpu-vunerabilities.txt
	fi
	cp /boot/config-`uname -r` $SHELLPACK_LOG/kconfig-`uname -r`.txt
	gzip -f $SHELLPACK_LOG/kconfig-`uname -r`.txt

	PROC_FILES="/proc/vmstat /proc/zoneinfo /proc/meminfo /proc/schedstat"
	for TEST in $MMTESTS; do
		export CURRENT_TEST=$TEST
		# Configure transparent hugepage support as configured
		reset_transhuge

		# Run installation-only step if supported
		grep -q INSTALL_ONLY $SCRIPTDIR/shellpacks/shellpack-bench-$CURRENT_TEST
		if [ $? -eq 0 ]; then
			echo Installing test $TEST
			export INSTALL_ONLY=yes
			./bin/run-single-test.sh $TEST
			unset INSTALL_ONLY
		fi

		# Run the test
		echo Starting test $TEST
		teststate_log "test begin :: $TEST `date +%s`"
		echo `date +%s` "run-mmtests: begin $TEST" >> $SHELLPACK_ACTIVITY

		# Record some files at start of test
		for PROC_FILE in $PROC_FILES; do
			sysstate_log "file start :: $PROC_FILE"
			sysstate_log "`cat $PROC_FILE`"
		done
		if [ -e /proc/lock_stat ]; then
			echo 0 > /proc/lock_stat
		fi
		if [ "`cat /proc/sys/kernel/stack_tracer_enabled 2> /dev/null`" = "1" ]; then
			sysstate_log "file start :: /sys/kernel/debug/tracing/stack_trace"
			sysstate_log "`cat /sys/kernel/debug/tracing/stack_trace`"
		fi
		RUNNING_TEST=$TEST

		# Set CPU idle latency limits
		CSTATE_PID=
		if [ "$CPUIDLE_CSTATE" != "" ]; then
			$EXPECT_UNBUFFER set-cstate-latency.pl --cstate $CPUIDLE_CSTATE &
			CSTATE_PID=$!
		fi
		if [ "$CPUIDLE_LATENCY" != "" ]; then
			$EXPECT_UNBUFFER set-cstate-latency.pl --latency $CPUIDLE_LATENCY &
			CSTATE_PID=$!
		fi
		if [ "$CPUIDLE_INDEX" != "" ]; then
			$EXPECT_UNBUFFER set-cstate-latency.pl --index $CPUIDLE_INDEX &
			CSTATE_PID=$!
		fi
		if [ "$CSTATE_PID" != "" ]; then
			ps -p $CSTATE_PID
			if [ $? -ne 0 ]; then
				die "CPU Cstate latency script is not running"
			fi
		fi

		# Run single test
		start_monitors
		/usr/bin/time -f "time :: $TEST %U user %S system %e elapsed" -o $SHELLPACK_LOG/timestamp \
			./bin/run-single-test.sh $TEST
		EXIT_CODE=$?
		stop_monitors

		# Kill CPU idle limited
		if [ -e /tmp/mmtests-cstate.pid ]; then
			kill -INT `cat /tmp/mmtests-cstate.pid`
			sleep 2
			if [ -e /tmp/mmtests-cstate.pid ]; then
				kill -9 `cat /tmp/mmtests-cstate.pid`
			fi
		fi

		# Record some basic information at end of test
		for PROC_FILE in $PROC_FILES; do
			sysstate_log "file end :: $PROC_FILE"
			sysstate_log "`cat $PROC_FILE`"
		done
		if [ "`cat /proc/sys/kernel/stack_tracer_enabled 2> /dev/null`" = "1" ]; then
			sysstate_log "file end :: /sys/kernel/debug/tracing/stack_trace"
			sysstate_log "`cat /sys/kernel/debug/tracing/stack_trace`"
		fi
		if [ -e /proc/lock_stat ]; then
			sysstate_log "file end :: /proc/lock_stat"
			sysstate_log "`cat /proc/lock_stat`"
		fi

		# Mark the finish of the test
		echo test exit :: $TEST $EXIT_CODE
		teststate_log "test end :: $TEST `date +%s`"
		teststate_log "`cat $SHELLPACK_LOG/timestamp`"
		rm $SHELLPACK_LOG/timestamp

		# Reset some parameters in case tests are sloppy
		hugeadm --pool-pages-min DEFAULT:0 2> /dev/null
		if [ "`lsmod | grep oprofile`" != "" ]; then
			opcontrol --stop   > /dev/null 2> /dev/null
			opcontrol --deinit > /dev/null 2> /dev/null
		fi

	done
	teststate_log "finish :: `date +%s`"
	dmesg > $SHELLPACK_LOG/dmesg
	gzip -f $SHELLPACK_LOG/dmesg

	if [ "$MMTEST_NUMA_POLICY" = "numad" ]; then
		echo Shutting down numad pid $NUMAD_PID
		kill $NUMAD_PID
		sleep 10
		mv /var/log/numad.log $SHELLPACK_LOG/numad-log
	fi

	echo `date +%s` "run-mmtests: Iteration $MMTEST_ITERATION end" >> $SHELLPACK_ACTIVITY
	echo Cleaning up
	for TEST in $MMTESTS; do
		uname -a > $SHELLPACK_LOG/kernel.version
	done

	if [ "$MEMCG_SIZE" != "" ]; then
		echo $$ >/cgroups/tasks
		rmdir /cgroups/[0-9]*
		umount /cgroups
	fi

	# Unconfigure swap
	case $SWAP_CONFIGURATION in
	partitions | swapfile)
		swapoff -a
		;;
	NFS)
		swapoff -a
		umount $SWAP_NFS_MOUNT
		;;
	nbd)
		swapoff -a
		nbd-client -d $SWAP_NBD_DEVICE
		;;
	default)
		;;
	esac

	# Unmount test disks
	umount_filesystems

	destroy_testdisk
done

# Restore system to original state
if [ "$STAP_USED" != "" ]; then
	stap-fix.sh --restore-only
fi

if [ "$EXPANDED_VMLINUX" = "yes" ]; then
	echo Recompressing vmlinux
	gzip /boot/vmlinux-`uname -r`
fi

if [ "$MMTESTS_FORCE_DATE" != "" ]; then
	MMTESTS_FORCE_DATE_END=`date +%s`
	OFFSET=$((MMTESTS_FORCE_DATE_END-MMTESTS_FORCE_DATE_START))
	date -s "$(echo $((MMTESTS_FORCE_DATE_BASE+OFFSET)) | awk '{print strftime("%c", $0)}')"
	echo Restoring after forced date update: `date`
	killall -CONT ntpd
fi

echo `date +%s` run-mmtests: End >> $SHELLPACK_ACTIVITY
teststate_log "status :: $EXIT_CODE"
gzip $SHELLPACK_SYSSTATEFILE
exit $EXIT_CODE
