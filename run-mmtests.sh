#!/bin/bash
. config
. $SHELLPACK_INCLUDE/common.sh

function die() {
        echo "FATAL: $@"
        exit -1
}

for DIRNAME in $SHELLPACK_TEMP $SHELLPACK_SOURCES $SHELLPACK_LOG; do
	if [ ! -e "$DIRNAME" ]; then
		mkdir -p "$DIRNAME"
	fi
done

for TEST in $MMTESTS; do
	rm -rf $SHELLPACK_LOG/$TEST
done

# Parse command-line arguments
ARGS=`getopt -o mn --long run-monitor,no-monitor -n run-mmtests -- "$@"`
eval set -- "$ARGS"
while true; do
	case "$1" in
		-m|--run-monitor)
			export RUN_MONITOR=yes
			shift
			;;
		-n|--no-monitor)
			export RUN_MONITOR=no
			shift
			;;
		*)
			export RUNNAME=$1
			break
			;;
	esac
done

# Take the default parameter as the run name
shift
if [ "$1" != "" ]; then
	RUNNAME=$1
fi

if [ "$RUN_MONITOR" = "no" ]; then
	unset MONITORS_PLAIN
	unset MONITORS_GZIP
	unset MONITORS_WITH_LATENCY
else
	if [ "$MONITORS_ALWAYS" = "" -a "$MONITORS_PLAIN" = "" -a "$MONITORS_GZIP" = "" -a "$MONITORS_WITH_LATENCY" = "" ]; then
		echo Monitors enabled but none configured
		exit
	fi
fi

EXPECT_UNBUFFER=expect_unbuffer
if [ "`which $EXPECT_UNBUFFER 2> /dev/null`" = "" ]; then
	EXPECT_UNBUFFER=unbuffer
fi

mkdir -p $SHELLPACK_LOG
mkdir -p $SHELLPACK_TEMP
mkdir -p $SHELLPACK_SOURCES

# Install libhugetlbfs if necessary
if [ "`which hugeadm 2> /dev/null`" = "" ]; then
	./shellpacks/shellpack-install-libhugetlbfsbuild -v 2.9
	export PATH=$SHELLPACK_SOURCES/libhugetlbfs-2.9-installed/bin:$PATH
	export PERL5LIB=$SHELLPACK_SOURCES/libhugetlbfs-2.9-installed/lib/perl5
	if [ "`which hugeadm`" = "" ]; then
		die Profiling requested but unable to provide
	fi
	cd $SHELLPACK_SOURCES/libhugetlbfs-2.9
	make install-stat
	cd -
fi

# Move oprofile helpers to right place (hack)
if [ ! -e /usr/lib/perl5/5.*/TLBC ]; then
	cp -r /usr/lib/perl5/TLBC /usr/lib/perl5/5.*/
fi

# Configure system parameters
echo Tuning the system for run: $RUNNAME monitor: $RUN_MONITOR
#hugeadm --create-global-mounts || exit
#hugeadm --pool-pages-max DEFAULT:8G || exit
#hugeadm --set-recommended-min_free_kbytes || exit
#hugeadm --set-recommended-shmmax || exit
if [ "$VM_DIRTY_RATIO" != "" ]; then
	sysctl -w vm.dirty_ratio=$VM_DIRTY_RATIO
fi

# Create RAID setup
if [ "$TESTDISK_RAID_PARTITIONS" != "" ]; then
	if [ -e $TESTDISK_RAID_DEVICE ]; then
		mdadm --stop $TESTDISK_RAID_DEVICE || exit
	fi

	echo "# partition table of /dev/sdb
unit: sectors

/dev/sdb1 : start=       $TESTDISK_RAID_OFFSET, size=  $TESTDISK_RAID_SIZE, Id=83
/dev/sdb2 : start=        0, size=        0, Id= 0
/dev/sdb3 : start=        0, size=        0, Id= 0
/dev/sdb4 : start=        0, size=        0, Id= 0" > /tmp/partition-table

	NR_DEVICES=0
	for PARTITION in $TESTDISK_RAID_PARTITIONS; do
		DISK=`echo $PARTITION | sed -e 's/[0-9]//'`
		sfdisk $DISK < /tmp/partition-table || die Failed to setup partition
		NR_DEVICES=$(($NR_DEVICES+1))
	done

	modprobe $TESTDISK_RAID_TYPE
	mdadm --create $TESTDISK_RAID_DEVICE -f -R -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS || exit

	# Create LVM device of a fixed name. This is in case the blktrace
	# monitor is in use. For reasons I did not bother tracking down,
	# blktrace does not capture events from MD devices properly on
	# at least kernel 3.0
	yes y | pvcreate -ff $TESTDISK_RAID_DEVICE || exit
	vgcreate mmtests-raid /dev/md0 || exit
	SIZE=`vgdisplay mmtests-raid | grep Free | grep PE | awk '{print $5}'`
	if [ "$SIZE" = "" ]; then
		die Failed to determine LVM size
	fi
	lvcreate -l $SIZE mmtests-raid -n lvm0 || exit

	# Consider the test partition to be the LVM volume
	export TESTDISK_PARTITION=/dev/mmtests-raid/lvm0

fi

# Create NBD device
if [ "$TESTDISK_NBD_DEVICE" != "" ]; then
	modprobe nbd || exit
	nbd-client -d $TESTDISK_NBD_DEVICE
	echo Connecting NBD client $TESTDISK_NBD_HOST $TESTDISK_NBD_PORT $TESTDISK_NBD_DEVICE
	nbd-client $TESTDISK_NBD_HOST $TESTDISK_NBD_PORT $TESTDISK_NBD_DEVICE || exit
	export TESTDISK_PARTITION=$TESTDISK_NBD_DEVICE
fi

# Create test disk
if [ "$TESTDISK_PARTITION" != "" ]; then
	if [ "$TESTDISK_FILESYSTEM" != "" -a "$TESTDISK_FILESYSTEM" != "tmpfs" ]; then
		echo Formatting test disk: $TESTDISK_FILESYSTEM
		mkfs.$TESTDISK_FILESYSTEM $TESTDISK_MKFS_PARAM $TESTDISK_PARTITION || exit
	fi

	echo Mounting test disk
	if [ "$TESTDISK_MOUNT_ARGS" = "" ]; then
		mount -t $TESTDISK_FILESYSTEM $TESTDISK_PARTITION $SHELLPACK_TEST_MOUNT || exit
	else
		mount -t $TESTDISK_FILESYSTEM $TESTDISK_PARTITION $SHELLPACK_TEST_MOUNT -o $TESTDISK_MOUNT_ARGS || exit
	fi

	echo Creating tmp and sources
	mkdir $SHELLPACK_SOURCES
	mkdir $SHELLPACK_TEMP
fi

# Create NFS mount
if [ "$TESTDISK_NFS_MOUNT" != "" ]; then
	/etc/init.d/nfs-common start
	mount -t nfs $TESTDISK_NFS_MOUNT $SHELLPACK_TEST_MOUNT || exit
fi

# Configure swap
case $SWAP_CONFIGURATION in
partitions)
	echo Disabling existing swap
	swapoff -a
	for SWAP_PART in $SWAP_PARTITIONS; do
		echo Enabling swap on partition $SWAP_PART
		swapon $SWAP_PART || die Failed to enable swap on $SWAP_PART
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

	MNTPNT=$SHELLPACK_TOPLEVEL/work/nfs-swapfile
	mkdir -p $MNTPNT || die "Failed to create NFS mount for swap"
	mount $SWAP_NFS_MOUNT $MNTPNT || die "Failed to mount NFS mount for swap"

	echo Disabling existing swap
	swapoff -a

	CREATE_SWAP=no
	if [ -e $MNTPNT/swapfile ]; then
		EXISTING_SIZE=`stat $MNTPNT/swapfile | grep Size: | awk '{print $2}'`
		EXISTING_SIZE=$((EXISTING_SIZE/1048576))
		if [ $EXISTING_SIZE -ne $SWAP_SWAPFILE_SIZEMB ]; then
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
	echo Using default swap configuration
	;;
esac
echo Swap configuration
swapon -s

# Configure low_latency if requested
if [ "$CFQ_LOW_LATENCY" != "" ]; then
	echo Configuring cfq low_latency == $CFQ_LOW_LATENCY
	cd /sys
	for PARAM in `find -name "low_latency"`; do
		echo $CFQ_LOW_LATENCY > $PARAM
	done
	cd -
fi

# Validate systemtap installation if it exists
STAP_USED=
for TEST in $MMTESTS; do
	if [ "$TEST" = "stress-highalloc" -o "$TEST" = "pagealloc" -o "$TEST" = "highalloc" ]; then
		STAP_USED=test-$TEST
	fi
done
for MONITOR in $MONITORS_ALWAYS $MONITORS_PLAIN $MONITORS_GZIP $MONITORS_WITH_LATENCY; do
	if [ "$MONITOR" = "dstate" -o "$MONITOR" = "stap-highorder-atomic" ]; then
		STAP_USED=monitor-$MONITOR
	fi
done
if [ "$STAP_USED" != "" ]; then
	if [ `which stap` = "" ]; then
		echo ERROR: systemtap required for $STAP_USED but not installed
		exit -1
	fi

	stap -e 'probe begin { println("validate systemtap") exit () }'
	if [ $? != 0 ]; then
		echo WARNING: systemtap installation broken, trying to fix.
		if [ ! -e /usr/share/systemtap/runtime/stack.c.orig ]; then
			cp /usr/share/systemtap/runtime/stack.c /usr/share/systemtap/runtime/stack.c.orig
		fi
		if [ ! -e /usr/share/systemtap/runtime/transport/relay_v2.c.orig ]; then
			cp /usr/share/systemtap/runtime/transport/relay_v2.c /usr/share/systemtap/runtime/transport/relay_v2.c.orig
		fi
		if [ ! -e /usr/share/systemtap/runtime/transport/transport.c.orig ]; then
			cp /usr/share/systemtap/runtime/transport/transport.c /usr/share/systemtap/runtime/transport/transport.c.orig
		fi

		# Restore original files and go through workarounds in order
		cp /usr/share/systemtap/runtime/stack.c.orig /usr/share/systemtap/runtime/stack.c
		cp /usr/share/systemtap/runtime/transport/relay_v2.c.orig /usr/share/systemtap/runtime/transport/relay_v2.c
		cp /usr/share/systemtap/runtime/transport/transport.c.orig /usr/share/systemtap/runtime/transport/transport.c

		stap -e 'probe begin { println("validate systemtap") exit () }'
		if [ $? != 0 ]; then
			sed /usr/share/systemtap/runtime/stack.c \
				-e 's/.warning = print_stack_warning/\/\/MMTESTS:.warning = print_stack_warning/' \
				-e 's/.warning_symbol = print_stack_warning_symbol,/\/\/MMTESTS:.warning_symbol = print_stack_warning_symbol,/' > /usr/share/systemtap/runtime/stack.c.tmp
			mv /usr/share/systemtap/runtime/stack.c.tmp /usr/share/systemtap/runtime/stack.c
			stap -e 'probe begin { println("validating systemtap fix") exit () }'
			if [ $? != 0 ]; then

				sed /usr/share/systemtap/runtime/transport/relay_v2.c \
					-e 's/int mode/umode_t mode/' > /usr/share/systemtap/runtime/transport/relay_v2.c.tmp
				mv /usr/share/systemtap/runtime/transport/relay_v2.c.tmp /usr/share/systemtap/runtime/transport/relay_v2.c
				sed /usr/share/systemtap/runtime/transport/transport.c \
					-e 's/fs_supers.next/fs_supers.first/' > /usr/share/systemtap/runtime/transport/transport.c.tmp
				mv /usr/share/systemtap/runtime/transport/transport.c.tmp /usr/share/systemtap/runtime/transport/transport.c

				stap -e 'probe begin { println("validating systemtap fix") exit () }'
				if [ $? != 0 ]; then
					mv /usr/share/systemtap/runtime/stack.c.orig /usr/share/systemtap/runtime/stack.c
					mv /usr/share/systemtap/runtime/transport/relay_v2.c.orig /usr/share/systemtap/runtime/transport/relay_v2.c
					mv /usr/share/systemtap/runtime/transport/transport.c.orig /usr/share/systemtap/runtime/transport/transport.c
					echo ERROR: systemtap required for $STAP_USED but installation is broken
					exit -1
				fi
			fi
		fi
	fi
fi

# If profiling is enabled, make sure the necessary oprofile helpers are
# available and that there is a unable vmlinux file in the expected
# place
export EXPANDED_VMLINUX=no
if [ "$SKIP_FINEPROFILE" = "no" -o "$SKIP_COARSEPROFILE" = "no" ]; then
	if [ "`which oprofile_start.sh`" = "" ]; then
		./shellpacks/shellpack-install-libhugetlbfsbuild -v 2.9
		export PATH=$SHELLPACK_SOURCES/libhugetlbfs-2.9-installed/bin:$PATH
		if [ "`which oprofile_start.sh`" = "" ]; then
			die Profiling requested but unable to provide
		fi
	fi

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

if [ "$RUN_MONITOR" = "yes" ]; then
	echo Configuring ftrace
	mount -t debugfs none /sys/kernel/debug
	#echo 1 > /sys/kernel/debug/tracing/events/kmem/mm_page_alloc_extfrag/enable
	#echo 1 > /sys/kernel/debug/tracing/events/vmscan/enable
	#echo 1 > /proc/sys/kernel/stack_tracer_enabled
fi

# Disable any inadvertent profiling going on right now
#oprofile --stop > /dev/null 2> /dev/null
#opcontrol --deinit > /dev/null 2> /dev/null

# Warm up. More appropriate warmup depends on the exact test
if [ "$SKIP_WARMUP" != "yes" ]; then
	echo Entering warmup
	./run-single-test.sh kernbench
	rm -rf $SHELLPACK_LOG/kernbench
	echo Warmup complete, beginning tests
else
	echo Skipping warmup run
fi
echo

function discover_script() {
	MONITOR_SCRIPT=./monitors/watch-$MONITOR
	if [ ! -e $MONITOR_SCRIPT ]; then
		MONITOR_SCRIPT=./monitors/watch-$MONITOR.sh
		if [ ! -e $MONITOR_SCRIPT ]; then
			MONITOR_SCRIPT=./monitors/watch-$MONITOR.pl
		fi
	fi
}

function start_monitors() {
	echo Starting monitors
	echo -n > monitor.pids
	for MONITOR in $MONITORS_ALWAYS; do
		discover_script
		export MONITOR_LOG=$SHELLPACK_LOG/$MONITOR-$RUNNAME-$TEST
		$EXPECT_UNBUFFER $MONITOR_SCRIPT > $MONITOR_LOG &
		echo $! >> monitor.pids
		echo Started monitor $MONITOR always pid `tail -1 monitor.pids`
	done
	for MONITOR in $MONITORS_PLAIN; do
		discover_script
		export MONITOR_LOG=$SHELLPACK_LOG/$MONITOR-$RUNNAME-$TEST
		$EXPECT_UNBUFFER $MONITOR_SCRIPT > $MONITOR_LOG &
		echo $! >> monitor.pids
		echo Started monitor $MONITOR plain pid `tail -1 monitor.pids`
	done
	for MONITOR in $MONITORS_GZIP; do
		discover_script
		export MONITOR_LOG=$SHELLPACK_LOG/$MONITOR-$RUNNAME-$TEST
		$EXPECT_UNBUFFER $MONITOR_SCRIPT | tee | gzip -c > $MONITOR_LOG.gz &
		PID1=$!
		sleep 5
		PID2=`./bin/piping-pid.sh $PID1`
		PID3=`./bin/piping-pid.sh $PID2`
		echo $PID3 >> monitor.pids
		echo $PID1 >> monitor.pids
		echo Started monitor $MONITOR gzip pid $PID3,$PID1
	done
	for MONITOR in $MONITORS_WITH_LATENCY; do
		discover_script
		export MONITOR_LOG=$SHELLPACK_LOG/$MONITOR-$RUNNAME-$TEST
		$EXPECT_UNBUFFER $MONITOR_SCRIPT | ./monitors/latency-output > $MONITOR_LOG &
		PID1=$!
		sleep 5
		PID2=`ps aux | grep watch-$MONITOR.sh | grep -v grep | grep -v expect | awk '{print $2}'`
		echo $PID2 >> monitor.pids
		echo $PID1 >> monitor.pids
		echo Started monitor $MONITOR latency pid $PID2,$PID1
	done
}

function stop_monitors() {
	# Shutdown monitors carefully. Time is given to allow monitors to
	# exit so processes like gzip do not get killed before they have
	# processed the full of their stdin
	sleep 5
	for PID in `cat monitor.pids`; do
		if [ "`ps h --pid $PID`" != "" ]; then
			echo -n "Shutting down monitor: $PID"
			kill $PID
			sleep 1

			while [ "`ps h --pid $PID`" != "" ]; do
				echo -n .
				sleep 1
			done
			echo
		else
			echo "Already exited: $PID"
		fi
	done
	rm monitor.pids
}

if [ "$MMTESTS_SIMULTANEOUS" != "yes" ]; then
	# Create memory control group if requested
	if [ "$MEMCG_SIZE" != "" ]; then
		mkdir -p /cgroups
		mount -t cgroup none /cgroups -o memory || die Failed to mount /cgroups
		mkdir /cgroups/0
		echo $MEMCG_SIZE > /cgroups/0/memory.limit_in_bytes || die Failed to set memory limit
		echo $$ > /cgroups/0/tasks
		echo Memory limit configured: `cat /cgroups/0/memory.limit_in_bytes`
	fi

	# Run tests in single mode
	echo start :: `date +%s` > $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	for TEST in $MMTESTS; do
		# Configure transparent hugepage support as configured
		reset_transhuge

		start_monitors

		# Run the test
		echo Starting test $TEST
		echo test begin :: $TEST `date +%s` >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME

		# Record some files at start of test
		echo file start :: /proc/vmstat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		cat /proc/vmstat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		echo file start :: /proc/zoneinfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		cat /proc/zoneinfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		echo file start :: /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		cat /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		if [ "`cat /proc/sys/kernel/stack_tracer_enabled`" = "1" ]; then
			echo file start :: /sys/kernel/debug/tracing/stack_trace >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
			cat /sys/kernel/debug/tracing/stack_trace >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		fi
		/usr/bin/time -f "time :: $TEST %U user %S system %e elapsed" -o $SHELLPACK_LOG/timestamp-$RUNNAME \
			./run-single-test.sh $TEST

		# Record some basic information at end of test
		echo file end :: /proc/vmstat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		cat /proc/vmstat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		echo file end :: /proc/zoneinfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		cat /proc/zoneinfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		echo file end :: /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		cat /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		if [ "`cat /proc/sys/kernel/stack_tracer_enabled`" = "1" ]; then
			echo file start :: /sys/kernel/debug/tracing/stack_trace >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
			cat /sys/kernel/debug/tracing/stack_trace >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		fi

		# Mark the finish of the test
		echo test end :: $TEST `date +%s` >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		cat $SHELLPACK_LOG/timestamp-$RUNNAME >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		rm $SHELLPACK_LOG/timestamp-$RUNNAME

		# Reset some parameters in case tests are sloppy
		hugeadm --pool-pages-min DEFAULT:0
		opcontrol --stop   > /dev/null 2> /dev/null
		opcontrol --deinit > /dev/null 2> /dev/null

		stop_monitors
	done
	echo finish :: `date +%s` >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
else
	# Create memory control group if requested
	if [ "$MEMCG_SIZE" != "" ]; then
		mkdir -p /cgroups
		mount -t cgroup none /cgroups -o memory || die Failed to mount /cgroups
	fi

	# Run tests in simultaneous mode
	START_TIME=`date +%s`
	MIN_END_TIME=$((START_TIME+MMTESTS_SIMULTANEOUS_DURATION))
	FORCE_END_TIME=$((START_TIME+MMTESTS_SIMULTANEOUS_MAX_DURATION))

	echo start :: $START_TIME > $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	echo file start :: /proc/vmstat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	cat /proc/vmstat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	echo file start :: /proc/zoneinfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	cat /proc/zoneinfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	echo file start :: /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	cat /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME

	start_monitors

	echo -n > test.pids
	NR_TEST=1
	while [ `date +%s` -lt $MIN_END_TIME ]; do
		for TEST in $MMTESTS; do
			CURRENTPID=`grep $TEST: test.pids | tail -1 | awk -F : '{print $2}'`
			TESTID=`grep $TEST: test.pids | tail -1 | awk -F : '{print $3}'`

			if [ "$MEMCG_SIZE" != "" -a ! -e /cgroups/$NR_TEST ]; then
				mkdir /cgroups/$NR_TEST
				echo $MEMCG_SIZE > /cgroups/$NR_TEST/memory.limit_in_bytes || die Failed to set memory limit
				echo Memory limit $NR_TEST configured: `cat /cgroups/$NR_TEST/memory.limit_in_bytes`
			fi

			# Start tests for the first time if necessary
			if [ "$CURRENTPID" = "" ]; then
				/usr/bin/time -f "time :: $TEST:$NR_TEST %U user %S system %e elapsed" -o $SHELLPACK_LOG/timestamp-mmtestsimul-$NR_TEST ./run-single-test.sh $TEST > $SHELLPACK_LOG/mmtests-log-$TEST-$NR_TEST.log 2>&1 &
				PID=$!
				echo Started first test $TEST pid $PID
				echo $TEST:$PID:$NR_TEST >> test.pids
				if [ "$MEMCG_SIZE" != "" ]; then
					echo $PID > /cgroups/$NR_TEST/tasks
				fi
				NR_TEST=$((NR_TEST+1))
				continue
			fi

			RUNNING=`ps h --pid $CURRENTPID`
			if [ "$RUNNING" = "" ]; then
				echo Completed test $TEST pid $CURRENTPID
				cat $SHELLPACK_LOG/timestamp-mmtestsimul-$TESTID >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
				rm $SHELLPACK_LOG/timestamp-mmtestsimul-$TESTID

				/usr/bin/time -f "time :: $TEST:$NR_TEST %U user %S system %e elapsed" -o $SHELLPACK_LOG/timestamp-mmtestsimul-$NR_TEST ./run-single-test.sh $TEST > $SHELLPACK_LOG/mmtests-log-$TEST-$NR_TEST.log 2>&1 &
				PID=$!
				echo Started test $TEST pid $PID
				echo $TEST:$PID:$NR_TEST >> test.pids
				if [ "$MEMCG_SIZE" != "" ]; then
					echo $PID > /cgroups/$NR_TEST/tasks
				fi
				NR_TEST=$((NR_TEST+1))
				continue
			fi
		done
		sleep 3
	done

	# Wait for current tests to exit
	for JOB in `cat test.pids`; do
		TEST=`echo $JOB | awk -F : '{print $1}'`
		PID=`echo $JOB | awk -F : '{print $2}'`
		TESTID=`echo $JOB | awk -F : '{print $3}'`

		if [ "`ps h --pid $PID`" != "" -a `date +%s` -lt $FORCE_END_TIME ]; then
			echo -n "Waiting on test $TEST to complete: $PID "
			while [ "`ps h --pid $PID`" != "" -a `date +%s` -lt $FORCE_END_TIME ]; do
				echo -n .
				sleep 10
			done

			cat $SHELLPACK_LOG/timestamp-mmtestsimul-$TESTID >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
			rm $SHELLPACK_LOG/timestamp-mmtestsimul-$TESTID
			echo
		fi
	done

	stop_monitors

	echo file end :: /proc/vmstat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	cat /proc/vmstat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	echo file end :: /proc/zoneinfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	cat /proc/zoneinfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	echo file end :: /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	cat /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	echo finish :: `date +%s` >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
fi

echo Cleaning up
for TEST in $MMTESTS; do
	uname -a > $SHELLPACK_LOG/$TEST/kernel.version
	rm -rf $SHELLPACK_LOG/$TEST-$RUNNAME
	mv $SHELLPACK_LOG/$TEST $SHELLPACK_LOG/$TEST-$RUNNAME
done
# Restore system to original state
if [ -e /usr/share/systemtap/runtime/stack.c.orig ]; then
	mv /usr/share/systemtap/runtime/stack.c.orig /usr/share/systemtap/runtime/stack.c
	mv /usr/share/systemtap/runtime/transport/relay_v2.c.orig /usr/share/systemtap/runtime/transport/relay_v2.c
	mv /usr/share/systemtap/runtime/transport/transport.c.orig /usr/share/systemtap/runtime/transport/transport.c
fi
if [ "$EXPANDED_VMLINUX" = "yes" ]; then
	echo Recompressing vmlinux
	gzip /boot/vmlinux-`uname -r`
fi
