#!/bin/bash
set ${MMTESTS_SH_DEBUG:-+x}
DEFAULT_CONFIG=config
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME" && pwd`
export PATH="$SCRIPTDIR/bin:$PATH"
RUNNING_TEST=
export EXPECT_UNBUFFER=$SCRIPTDIR/bin/unbuffer
export BUILDONLY=false
export DELETE_ON_EXIT_FILE=$(mktemp /tmp/mmtest-cleanup-XXXXXXXXX)

# External optimisations and tuning can be specified via the build-flags
# repository. Set the defaults to use compiler optimisations if available
# but not mpiflags or sysctls. Generally mpiflags and sysctls are used
# for peak configurations on specific platforms
BUILDFLAGS_ENABLE_COMPILEFLAGS=${BUILDFLAGS_ENABLE_COMPILEFLAGS:-yes}
BUILDFLAGS_ENABLE_MPIFLAGS=${BUILDFLAGS_ENABLE_MPIFLAGS:-no}
BUILDFLAGS_ENABLE_SYSCTL=${BUILDFLAGS_ENABLE_SYSCTL:-no}

INTERRUPT_COUNT=0
clean_exit()
{
	while read file; do
		[ -n "$file" ] && rm -rf $file
	done < $DELETE_ON_EXIT_FILE
	rm -f $DELETE_ON_EXIT_FILE
	if [ "$MMTESTS_SESSION_ID" != "" ]; then
		rm -f /tmp/packages.$MMTESTS_SESSION_ID
	fi

	if [ "$OFFLINED_MEMORY" = "1" ]; then
		online-memory
	fi
}

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
	clean_exit
}

trap begin_shutdown SIGTERM
trap begin_shutdown SIGINT
trap clean_exit EXIT

usage() {
	echo "$0 [-mnpbh] [-c path_to_config] runname"
	echo
	echo "-m|--run-monitor Force enable monitor."
	echo "-n|--no-monitor  Force disable monitor."
	echo "-p|--performance Force performance CPUFreq governor before starting the tests."
	echo "-c|--config      Use MMTests config, default is ./config, more than one can be specified"
	echo "-b|--build-only  Only build the software to test, don't run"
	echo "   --mount-only  Only mount test disk."
	echo "   --no-mount    Don't mount test disk."
	echo "-h|--help        Prints this help."
}

# For `getopt`, which is needed *now*!
install-depends util-linux

# Parse command-line arguments
ARGS=`getopt -o pmnc:bh --long performance,help,run-monitor,no-monitor,config: \
			--long build-only,mount-only,no-mount \
			-n run-mmtests -- "$@"`
declare -a CONFIGS
export CONFIGS
eval set -- "$ARGS"
while true; do
	case "$1" in
		-h|--help)
			perldoc ${BASH_SOURCE[0]}
			exit $SHELLPACK_SUCCESS
			;;
		-p|--performance)
			export FORCE_PERFORMANCE_SETUP=yes
			shift
			;;
		-m|--run-monitor)
			export FORCE_RUN_MONITOR=yes
			shift
			;;
		-n|--no-monitor)
			export FORCE_RUN_MONITOR=no
			shift
			;;
		-c|--config)
			DEFAULT_CONFIG=
			CONFIGS+=( "$2" )
			shift 2
			;;
		-b|--build-only)
		        BUILDONLY=true
		        shift
			;;
		--no-mount)
			NOMOUNT=true
			shift
			;;
		--mount-only)
			MOUNTONLY=true
			shift
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

# Remove stale bash_arrays file
rm -f $SCRIPTDIR/bash_arrays

# Remove stale shellpacks
rm -f $SCRIPTDIR/shellpacks/shellpack-*

# Remove stale merged install directories
if [ -d $SCRIPTDIR/work/sources/ ]; then
	find $SCRIPTDIR/work/sources/ -maxdepth 1 -type d -name "*deps-installed" -exec rm -rf {} \;
fi

# required in common.sh
install-depends awk

. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/shellpacks/monitors.sh
export SHELLPACK_ADDON=$SCRIPTDIR/shellpack_src/addon

# Required in get_numa_details when importing config
install-depends numactl

# Import MMTests configuration files
import_configs

# Create directories that must exist
cd $SHELLPACK_TOPLEVEL

setup_slurm_env
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

# Force artificial date is requested
if ! $BUILDONLY && [ "$MMTESTS_FORCE_DATE" != "" ]; then
	killall -STOP ntpd
	MMTESTS_FORCE_DATE_BASE=`date +%s`
	date -s "$MMTESTS_FORCE_DATE"
	MMTESTS_FORCE_DATE_START=`date +%s`
	echo Forcing reset of date: `date`
fi

# Install packages that are generally needed by a large number of tests
install-depends autoconf automake bc binutils-devel btrfsprogs bzip2	\
	coreutils cpupower e2fsprogs expect expect-devel gcc hdparm	\
	hwloc libtool make patch perl-Time-HiRes psmisc tcl	\
	time wget xfsprogs xfsprogs-devel xz which perl-File-Slurp netcat-openbsd \
	gzip hostname iproute2

# if we're running in a vm, and the firewall seems on, let's (try to) whitelist
# the host, so we can communicate with it. this should work fine if we're using
# firewalld/firewall-cmd. if not, for now, we just (desperately) try something
# with iptables, but I can't be sure it'll work equally well.
if [ ! -z "$MMTESTS_HOST_IP" ]; then
	if command -v firewall-cmd &> /dev/null && [ "$(firewall-cmd --state)" = "running" ]; then
		#firewall-cmd  --add-rich-rule='rule family="ipv4" source address="${MMTESTS_HOST_IP}" port protocol="tcp" port="4321" accept'
		firewall-cmd --zone=trusted --add-source=${MMTESTS_HOST_IP}
	elif command -v iptables &> /dev/null; then
		iptables -A INPUT -p tcp --dport ${MMTESTS_GUEST_PORT:-4321} -j ACCEPT
	fi
fi

# Set some basic performance cpu frequency settings.
if ! $BUILDONLY && [ "$FORCE_PERFORMANCE_SETUP" = "yes" ]; then
	FORCE_PERFORMANCE_SCALINGGOV_BASE=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
	NOTURBO="/sys/devices/system/cpu/intel_pstate/no_turbo"
	[ -f $NOTURBO ] && FORCE_PERFORMANCE_NOTURBO_BASE=`cat $NOTURBO`
	force_performance_setup
fi

OFFLINED_MEMORY=0
if [ "$MMTESTS_LIMIT_MEMORY" != "" ]; then
	offline-memory $MMTESTS_LIMIT_MEMORY || die "Failed to limit memory to $MMTESTS_LIMIT_MEMORY bytes"
	OFFLINED_MEMORY=1
fi

# Check monitoring
if ! $BUILDONLY && [ "$FORCE_RUN_MONITOR" != "" ]; then
	RUN_MONITOR=$FORCE_RUN_MONITOR
fi
if [ "$RUN_MONITOR" = "no" ]; then
	# Disable monitor
	unset MONITORS_GZIP
	unset MONITORS_WITH_LATENCY
	unset MONITORS_TRACER
else
	# Check at least one monitor is enabled
	if [ "$MONITORS_ALWAYS" = "" -a "$MONITORS_GZIP" = "" -a "$MONITORS_WITH_LATENCY" = "" -a "$MONITORS_TRACER" = "" ]; then
		echo WARNING: Monitors enabled but none configured
	fi
fi

# Generate shellpack from template
export SHELLPACK_LOG_RUNBASE=$SHELLPACK_LOG_BASE/$RUNNAME
export SHELLPACK_LOG=$SHELLPACK_LOG_RUNBASE/iter-1
echo Building shellpacks
for TEST in $MMTESTS; do
	$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh $TEST
done
echo

# Validate systemtap installation if it exists
TESTS_STAP="highalloc pagealloc highalloc"
MONITORS_STAP="dstate stap-highorder-atomic function-frequency syscalls"
export STAP_USED=
export MONITOR_STAP=
for TEST in $MMTESTS; do
	for CHECK in $TESTS_STAP; do
		if [ "$TEST" = "$CHECK" ]; then
			STAP_USED=test-$TEST
		fi
	done
done
check_monitor_stap
if [ "$STAP_USED" != "" ]; then
	fixup_stap
fi

if $BUILDONLY; then
    export INSTALL_ONLY=yes
    for TEST in $MMTESTS; do
	./bin/run-single-test.sh $TEST ${RUNNAME}
	if [ $? -ne 0 ]; then
            die "Installation step failed for $TEST"
        fi
    done
    exit 0
fi

# If profiling is enabled, make sure the necessary oprofile helpers are
# available and that there is a unable vmlinux file in the expected
# place
export EXPANDED_VMLINUX=no
NR_HOOKS=`ls profile-hooks* 2> /dev/null | wc -l`
if [ $NR_HOOKS -gt 0 ]; then
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

if [ "$TESTDISK_NOMOUNT" == "true" ] ; then
    NOMOUNT="true"
fi

install_numad
install_tuned

MMTEST_ITERATIONS=${MMTEST_ITERATIONS:-1}
export SHELLPACK_LOG_RUNBASE=$SHELLPACK_LOG_BASE/$RUNNAME
# Delete old runs
rm -rf $SHELLPACK_LOG_RUNBASE &>/dev/null
mkdir -p $SHELLPACK_LOG_RUNBASE

mmtests_wait_token "mmtests_start"

for (( MMTEST_ITERATION = 0; MMTEST_ITERATION < $MMTEST_ITERATIONS; MMTEST_ITERATION++ )); do
	export SHELLPACK_LOG=$SHELLPACK_LOG_RUNBASE/iter-$MMTEST_ITERATION
	export SHELLPACK_ACTIVITY="$SHELLPACK_LOG/tests-activity"
	mkdir -p $SHELLPACK_LOG
	activity_log "run-mmtests: Start"

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

	if [ -n "${TESTDISK_MIN_SIZE}" ] ; then
		for disk in ${TESTDISK_PARTITION[*]} ; do
			SIZE=`blockdev --getsize64 $disk`
			if [ "$SIZE" = "" -o "$SIZE" = "0" ]; then
				echo "`hostname`: Tried blockdev --getsize64 $disk"
				die "Unable to detect test partition $disk size ($SIZE)"
			fi

			if [ $SIZE -le $TESTDISK_MIN_SIZE ]; then
				die "Test disk partition is too small"
			fi
		done
	fi

	# Export variables needed for successful setup of filesystems
	export STORAGE_CACHE_TYPE STORAGE_CACHING_DEVICE STORAGE_BACKING_DEVICE
	export TESTDISK_PARTITIONS
	export TESTDISK_FILESYSTEM
	export TESTDISK_FS_SIZE
	export TESTDISK_MKFS_PARAM
	export TESTDISK_MOUNT_ARGS
	export TESTDISK_NOMOUNT
	export TESTDISK_NFS_MOUNT
	export SHELLPACK_TEST_MOUNTS
	export SHELLPACK_DATA_DIRS

	setup_io_scheduler

	# format disk, mount testdisk
	if [ "$NOMOUNT" != "true" ]; then
		create_filesystems
		if [ "$MOUNTONLY" = "true" ]; then
			exit 0;
		fi
	fi

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

	export SHELLPACK_LOGFILE="$SHELLPACK_LOG/tests-timestamp"
	export SHELLPACK_SYSSTATEFILE="$SHELLPACK_LOG/tests-sysstate"
	activity_log "run-mmtests: Iteration $MMTEST_ITERATION start"

	start_numad
	start_tuned

	EXIT_CODE=$SHELLPACK_SUCCESS

	# Run tests in single mode
	rm -f $SHELLPACK_LOGFILE $SHELLPACK_SYSSTATEFILE
	teststate_log "start :: `date +%s`"
	if [ "$RAID_CREATE_END" != "" ]; then
		teststate_log "raid-create :: $((RAID_CREATE_END-RAID_CREATE_START))"
	fi
	sysstate_log_basic_info
	collect_hardware_info
	collect_kernel_info
	collect_sysconfig_info

	for TEST in $MMTESTS; do
		export CURRENT_TEST=$TEST
		# Configure transparent hugepage support as configured
		reset_transhuge

		# Run installation-only steps
		echo Installing test $TEST
		export INSTALL_ONLY=yes
		./bin/run-single-test.sh $TEST ${RUNNAME}
		if [ $? -ne 0 ]; then
			die "Installation step failed for $TEST"
		fi
		unset INSTALL_ONLY

		# Run the test
		echo Starting test $TEST
		teststate_log "test begin :: $TEST `date +%s`"
		activity_log "run-mmtests: begin $TEST"

		# Record some basic information at start of test
		sysstate_log_proc_files "start"
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
		sync
		start_monitors

		mmtests_wait_token "test_do"

		setup_cgroups
		export cg_tasks=${CGROUP_TASKS[@]}
		if [ ${#CGROUP_TASKS[@]} -gt 0 ]; then
			bash -c "for i in $cg_tasks; do echo \$$ > \${i}; done &&
				/usr/bin/time -f \"time :: $TEST %U user %S system %e elapsed\" \
				-o $SHELLPACK_LOG/timestamp ./bin/run-single-test.sh $TEST ${RUNNAME}"
		else
			/usr/bin/time -f "time :: $TEST %U user %S system %e elapsed" -o $SHELLPACK_LOG/timestamp \
				./bin/run-single-test.sh $TEST ${RUNNAME}
		fi
		EXIT_CODE=$?

		sync
		stop_monitors

		mmtests_wait_token "test_done"

		# Kill CPU idle limited
		if [ -e /tmp/mmtests-cstate.pid ]; then
			kill -INT `cat /tmp/mmtests-cstate.pid`
			sleep 2
			if [ -e /tmp/mmtests-cstate.pid ]; then
				kill -9 `cat /tmp/mmtests-cstate.pid`
			fi
		fi

		# Record some basic information at end of test
		sysstate_log_proc_files "end"
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
	journalctl -k 2>/dev/null > $SHELLPACK_LOG/journalctl-kernel
	gzip -f $SHELLPACK_LOG/journalctl-kernel
	gzip -f $SHELLPACK_SYSSTATEFILE

	shutdown_numad
	shutdown_tuned

	activity_log "run-mmtests: Iteration $MMTEST_ITERATION end"
	echo Cleaning up

	if [ "$RUN_MONITOR" = "yes" ]; then
		for STRAY in `ps auxw | grep watch- | grep unbuffer | awk '{print $2}'`; do
			echo o Killing stray monitor $STRAY
			kill -9 $STRAY
		done
	fi

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
	if [ "$NOMOUNT" != "true" ]; then
		umount_filesystems
	fi

	destroy_testdisk
done

mmtests_wait_token "mmtests_end"

# Restore system to original state
if [ "$STAP_USED" != "" ]; then
	stap-fix.sh --restore-only
fi

if [ "$EXPANDED_VMLINUX" = "yes" ]; then
	echo Recompressing vmlinux
	gzip /boot/vmlinux-`uname -r`
fi

if [ "$FORCE_PERFORMANCE_SETUP" = "yes" ]; then
	restore_performance_setup $FORCE_PERFORMANCE_SCALINGGOV_BASE $FORCE_PERFORMANCE_NOTURBO_BASE
fi


if [ "$MMTESTS_FORCE_DATE" != "" ]; then
	MMTESTS_FORCE_DATE_END=`date +%s`
	OFFSET=$((MMTESTS_FORCE_DATE_END-MMTESTS_FORCE_DATE_START))
	date -s "$(echo $((MMTESTS_FORCE_DATE_BASE+OFFSET)) | awk '{print strftime("%c", $0)}')"
	echo Restoring after forced date update: `date`
	killall -CONT ntpd
fi

activity_log "run-mmtests: End"
teststate_log "status :: $EXIT_CODE"
exit $EXIT_CODE

: <<=cut
=pod

=head1 NAME

run-mmtests.sh - Install and execute a set of tests as specified by a configuration file

=head1 SYNOPSIS

run-mmtests B[options] test-name

 Options:
 -m, --run-monitors	Run with monitors enabled as specified by the configuration
 -n, --no-monitor	Only execute the benchmark, do not monitor it
 -p, --performance	Set the performance cpufreq governor before starting
 -c, --config		Configuration file to read (default: config)
 -b, --build-only	Only build the benchmark, do not execute it
     --mount-only	Only mount test disk
     --no-mount		Don't mount test disk
 -h, --help		Print this help

=head1 DESCRIPTION

B<run-mmtests.sh> is for test installation and execution. If monitors
are enabled, they start monitoring after the benchmark has been installed
and configured.

The B<test-name> can be anything and only specifies the name of the
directory under B<work/log> so uniquely identify the test. An obvious
example is using the kernel name or the name of a patch. It could also
be based on changing userspace packages, the benchmark configuration,
system tuning or different machine names.

The work/log/test-name directory will have all the raw logs of the
benchmark itself, any monitoring and some basic information about the
machine configuration for offline analysis.

=head1 EXAMPLE

$ ./bin/autogen-configs

$ ./run-mmtests.sh --no-monitor --config configs/config-pagealloc-performance 5.8-vanilla

$ ./run-mmtests.sh --no-monitor --config configs/config-pagealloc-performance 5.9-vanilla

=head1 AUTHOR

B<Mel Gorman <mgorman@techsingularity.net>>

=head1 REPORTING BUGS

Report bugs to the author.
