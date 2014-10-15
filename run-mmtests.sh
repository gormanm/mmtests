#!/bin/bash
DEFAULT_CONFIG=config
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME" && pwd`
RUNNING_TEST=
KVM=

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
RUNNAME=$1
export MMTEST_ITERATION=$2

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

. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
if [ -n "$MMTEST_ITERATION" ]; then
	export SHELLPACK_LOG="$SHELLPACK_LOG/$MMTEST_ITERATION"
fi

for ((i = 0; i < ${#CONFIGS[@]}; i++ )); do
	source "${CONFIGS[$i]}"
done

# Create directories that must exist
cd $SHELLPACK_TOPLEVEL
for TEST in $MMTESTS; do
	rm -rf $SHELLPACK_LOG/$TEST
done
for DIRNAME in $SHELLPACK_SOURCES $SHELLPACK_LOG; do
	if [ ! -e "$DIRNAME" ]; then
		mkdir -p "$DIRNAME"
	fi
done

# Mount the log directory on the requested partition if requested
if [ "$LOGDISK_PARTITION" != "" ]; then
	echo Unmounting log partition: $SHELLPACK_LOG
	umount $SHELLPACK_LOG

	echo $LOGDISK_PARTITION | grep \/ram
	if [ $? -eq 0 ]; then
		modprobe brd
	fi

	if [ "$LOGDISK_FILESYSTEM" != "" -a "$LOGDISK_FILESYSTEM" != "tmpfs" ]; then
		echo Formatting log disk: $LOGDISK_FILESYSTEM
		mkfs.$LOGDISK_FILESYSTEM $LOGDISK_MKFS_PARAM $LOGDISK_PARTITION || exit
	fi

	echo Mounting log disk
	if [ "$LOGDISK_MOUNT_ARGS" = "" ]; then
		mount -t $LOGDISK_FILESYSTEM $LOGDISK_PARTITION $SHELLPACK_LOG || exit
	else
		mount -t $LOGDISK_FILESYSTEM $LOGDISK_PARTITION $SHELLPACK_LOG -o $LOGDISK_MOUNT_ARGS || exit
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
	rm -rf work/log/*-$RUNNAME

	RCMD="ssh -p 30022 root@localhost"

	echo Executing mmtest inside KVM: run-mmtests.sh $KVM_ARGS $RUNNAME
	echo MMtests toplevel: $SHELLPACK_TOPLEVEL
	echo MMTests logs: $SHELLPACK_LOG
	$RCMD "cd $SHELLPACK_TOPLEVEL && ./run-mmtests.sh $KVM_ARGS $RUNNAME"
	RETVAL=$?
	echo Copying KVM logs
	scp -r -P 30022 "root@localhost:$SHELLPACK_LOG/*" "$SHELLPACK_LOG/"
	scp -r -P 30022 "root@localhost:$SHELLPACK_TOPLEVEL/kvm-console.log" "$SHELLPACK_LOG/kvm-console.log-$RUNNAME"

	echo Shutting down KVM
	$RCMD shutdown -h now
	sleep 30
	kill -9 `cat qemu.pid`
	rm -f qemu.pid
	exit $RETVAL
fi

# Install packages that are generally needed by a large number of tests
install-depends autoconf automake binutils-devel bzip2 dosfstools expect \
	expect-devel gcc gcc-32bit libhugetlbfs libtool make oprofile patch \
	recode systemtap xfsprogs xfsprogs-devel psmisc btrfsprogs xz wget \
	perl-Time-HiRes time
install-depends kpartx util-linux

# Following packages only interesting when running virtual machines
#install-depends libvirt-daemon-driver-qemu libvirt-daemon-qemu qemu virt-manager

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
		echo Monitors enabled but none configured
		exit $SHELLPACK_ERROR
	fi

	# Check that expect_unbuffer is installed
	EXPECT_UNBUFFER=expect_unbuffer
	if [ "`which $EXPECT_UNBUFFER 2> /dev/null`" = "" ]; then
		EXPECT_UNBUFFER=unbuffer
		if [ "`which $EXPECT_UNBUFFER 2> /dev/null`" = "" ]; then
			echo Monitoring enabled but expect_unbuffer is not installed.
			echo Install the expect-devel package or equivalent
			exit $SHELLPACK_ERROR
		fi
	fi
fi

# Configure system parameters
echo Tuning the system for run: $RUNNAME monitor: $RUN_MONITOR
if [ "$VM_DIRTY_RATIO" != "" ]; then
	sysctl -w vm.dirty_ratio=$VM_DIRTY_RATIO
fi

# Create RAID setup
if [ "$TESTDISK_RAID_DEVICES" != "" ]; then
	DEVICE=`echo $TESTDISK_RAID_DEVICES | awk '{print $1}'`
	BASE_DEVICE=`basename $DEVICE`
	MD_DEVICE=`grep $BASE_DEVICE /proc/mdstat | awk '{print $1}'`

	if [ "$MD_DEVICE" != "" ]; then
		echo Cleaning up old device
		vgremove -f mmtests-raid
		mdadm --remove $TESTDISK_RAID_MD_DEVICE
		mdadm --remove /dev/$MD_DEVICE
		mdadm --stop $TESTDISK_RAID_MD_DEVICE
		mdadm --stop /dev/$MD_DEVICE
		mdadm --remove $TESTDISK_RAID_MD_DEVICE
		mdadm --remove /dev/$MD_DEVICE
	fi

	# Convert to megabytes
	TESTDISK_RAID_OFFSET=$((TESTDISK_RAID_OFFSET/1048576))
	TESTDISK_RAID_SIZE=$((TESTDISK_RAID_SIZE/1048576))
	TESTDISK_RAID_PARTITIONS=

	NR_DEVICES=0
	for DISK in $TESTDISK_RAID_DEVICES; do
		echo
		echo Deleting partitions on disk $DISK
		parted -s $DISK mktable msdos

		echo Creating partitions on $DISK
		parted -s --align optimal $DISK mkpart primary $TESTDISK_RAID_OFFSET $TESTDISK_RAID_SIZE || die Failed to create aligned partition with parted
		ATTEMPT=0
		OUTPUT=`mdadm --zero-superblock ${DISK}1 2>&1 | grep "not zeroing"`
		while [ "$OUTPUT" != "" ]; do
			echo Retrying superblock zeroing of ${DISK}1
			sleep 1
			mdadm --zero-superblock ${DISK}1
			OUTPUT=`mdadm --zero-superblock ${DISK}1 2>&1 | grep "not zeroing"`
			ATTEMPT=$((ATTEMPT+1))
			if [ $ATTEMPT -eq 5 ]; then
				die Failed to zero superblock of ${DISK}1
			fi
		done

		NR_DEVICES=$(($NR_DEVICES+1))
		TESTDISK_RAID_PARTITIONS="$TESTDISK_RAID_PARTITIONS ${DISK}1"
	done

	echo Creation start: `date`
	echo Creating RAID device $TESTDISK_RAID_MD_DEVICE $TESTDISK_RAID_TYPE
	case $TESTDISK_RAID_TYPE in
	raid1)
		# Force use with just two disks
		NR_DEVICES=0
		SUBSET=
		for PART in $TESTDISK_RAID_PARTITIONS; do
			if [ $NR_DEVICES -eq 2 ]; then
				continue
			fi
			if [ "$SUBSET" = "" ]; then
				SUBSET=$PART
			else
				SUBSET="$SUBSET $PART"
			fi
			NR_DEVICES=$((NR_DEVICES+1))
		done
		export TESTDISK_RAID_PARTITIONS=$SUBSET
		echo mdadm --create $TESTDISK_RAID_MD_DEVICE -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
		EXPECT_SCRIPT=`mktemp`
		cat > $EXPECT_SCRIPT <<EOF
spawn mdadm --create $TESTDISK_RAID_MD_DEVICE -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
expect {
	"Continue creating array?" { send yes\\r; exp_continue}
}
EOF
		expect -f $EXPECT_SCRIPT || exit -1
		rm $EXPECT_SCRIPT
		;;
	raid5)
		echo mdadm --create $TESTDISK_RAID_MD_DEVICE --bitmap=internal -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
		mdadm --create $TESTDISK_RAID_MD_DEVICE --bitmap=internal -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS || exit
		;;
	*)
		echo mdadm --create $TESTDISK_RAID_MD_DEVICE -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
		mdadm --create $TESTDISK_RAID_MD_DEVICE -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS || exit
		;;
	esac

	echo Waiting on sync to finish
	mdadm --misc --wait $TESTDISK_RAID_MD_DEVICE

	echo Dumping final md state
	cat /proc/mdstat			| tee    md-stat-$RUNNAME
	mdadm --detail $TESTDISK_RAID_MD_DEVICE | tee -a md-stat-$RUNNAME

	# Create LVM device of a fixed name. This is in case the blktrace
	# monitor is in use. For reasons I did not bother tracking down,
	# blktrace does not capture events from MD devices properly on
	# at least kernel 3.0
	yes y | pvcreate -ff $TESTDISK_RAID_MD_DEVICE || exit
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

# Create ram disk
if [ "$TESTDISK_RD_SIZE" != "" ]; then
	if [ -e /dev/ram0 ]; then
		umount /dev/ram0 &>/dev/null
		rmmod brd
	fi
	modprobe brd rd_size=$((TESTDISK_RD_SIZE/1024))
	export TESTDISK_PARTITION=/dev/ram0
	if [ "$TESTDISK_RD_PREALLOC" == "yes" ]; then
		if [ "$TESTDISK_RD_PREALLOC_NODE" != "" ]; then
			tmp_prealloc_cmd="numactl -N $TESTDISK_RD_PREALLOC_NODE"
		else
			tmp_prealloc_cmd="numactl -i all"
		fi
		$tmp_prealloc_cmd dd if=/dev/zero of=$TESTDISK_PARTITION bs=1M &>/dev/null
	fi
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
	mkdir -p $SHELLPACK_SOURCES
	mkdir -p $SHELLPACK_TEMP
fi

# Create NFS mount
if [ "$TESTDISK_NFS_MOUNT" != "" ]; then
	/etc/init.d/nfs-common start
	/etc/init.d/rpcbind start
	mount -t nfs $TESTDISK_NFS_MOUNT $SHELLPACK_TEST_MOUNT || exit
fi

# Prepared environment in a directory, does not work together with
# TESTDISK_PARTITION and co.
if [ "$TESTDISK_DIR" != "" ]; then
	if [ "$SHELLPACK_TEST_MOUNT" != "" -a "$TESTDISK_PARTITION" != "" ]; then
		die "Can't use TESTDISK_PARTITION together with TESTDISK_DIR"
	fi
	if ! [ -d "$TESTDISK_DIR" ]; then
		die "Can't find TESTDISK_DIR $TESTDISK_DIR"
	fi
	echo "Using directory $TESTDISK_DIR for test"
else
	if [ "$SHELLPACK_TEST_MOUNT" != "" -a "$TESTDISK_PARTITION" != "" ]; then
		echo "Using TESTDISK_DIR at SHELLPACK_TEST_MOUNT"
		TESTDISK_DIR="$SHELLPACK_TEMP"
	else
		echo "Using default TESTDISK_DIR"
		TESTDISK_DIR="$SHELLPACK_TEMP"
		mkdir -p "$SHELLPACK_TEMP"
	fi
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
TESTS_STAP="stress-highalloc pagealloc highalloc"
MONITORS_STAP="dstate stap-highorder-atomic function-frequency"
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
		exit $SHELLPACK_ERROR
	fi
fi

# If profiling is enabled, make sure the necessary oprofile helpers are
# available and that there is a unable vmlinux file in the expected
# place
export EXPANDED_VMLINUX=no
if [ "$SKIP_FINEPROFILE" = "no" -o "$SKIP_COARSEPROFILE" = "no" ]; then
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

# Warm up. More appropriate warmup depends on the exact test
if [ "$SKIP_WARMUP" != "yes" ]; then
	echo Entering warmup
	RUNNING_TEST=kernbench
	./run-single-test.sh kernbench
	RUNNING_TEST=
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
	for MONITOR in $MONITORS_TRACER; do
		discover_script
		export MONITOR_LOG=$SHELLPACK_LOG/$MONITOR-$RUNNAME-$TEST
		export MONITOR_PID=$SHELLPACK_LOG/$MONITOR-$RUNNAME-$TEST.pid
		$EXPECT_UNBUFFER $MONITOR_SCRIPT &

		ATTEMPT=1
		while [ ! -e $MONITOR_PID ]; do
			sleep 1
			ATTEMPT=$((ATTEMPT+1))
			if [ $ATTEMPT -gt 10 ]; then
				die "Waited 10 seconds for $MONITOR to start but no sign of it."
			fi
		done

		PID1=`cat $MONITOR_PID`
		rm $MONITOR_PID
		echo $PID1 >> monitor.pids
		echo Started monitor $MONITOR tracer pid $PID1
	done

	if [ "$MONITOR_STAP" != "" ]; then
		echo Sleeping 30 seconds to give stap monitors change to load
		sleep 30
	fi
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
		mkdir -p /cgroups/0
		echo $MEMCG_SIZE > /cgroups/0/memory.limit_in_bytes || die Failed to set memory limit
		echo $$ > /cgroups/0/tasks
		echo Memory limit configured: `cat /cgroups/0/memory.limit_in_bytes`
	fi

	EXIT_CODE=$SHELLPACK_SUCCESS

	# Run tests in single mode
	dmesg > $SHELLPACK_LOG/dmesg-$RUNNAME
	echo start :: `date +%s` > $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	echo arch :: `uname -m` >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	if [ "`which numactl 2> /dev/null`" != "" ]; then
		numactl --hardware >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	fi
	PROC_FILES="/proc/vmstat /proc/zoneinfo /proc/meminfo /proc/schedstat"
	for TEST in $MMTESTS; do
		# Configure transparent hugepage support as configured
		reset_transhuge

		start_monitors

		# Run the test
		echo Starting test $TEST
		echo test begin :: $TEST `date +%s` >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME

		# Record some files at start of test
		for PROC_FILE in $PROC_FILES; do
			echo file start :: $PROC_FILE >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
			cat $PROC_FILE >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		done
		cat /proc/meminfo >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		if [ -e /proc/lock_stat ]; then
			echo 0 > /proc/lock_stat
		fi
		if [ "`cat /proc/sys/kernel/stack_tracer_enabled 2> /dev/null`" = "1" ]; then
			echo file start :: /sys/kernel/debug/tracing/stack_trace >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
			cat /sys/kernel/debug/tracing/stack_trace >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		fi
		RUNNING_TEST=$TEST
		/usr/bin/time -f "time :: $TEST %U user %S system %e elapsed" -o $SHELLPACK_LOG/timestamp-$RUNNAME \
			./run-single-test.sh $TEST
		EXIT_CODE=$?

		# Record some basic information at end of test
		for PROC_FILE in $PROC_FILES; do
			echo file end :: $PROC_FILE >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
			cat $PROC_FILE >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		done
		if [ "`cat /proc/sys/kernel/stack_tracer_enabled 2> /dev/null`" = "1" ]; then
			echo file end :: /sys/kernel/debug/tracing/stack_trace >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
			cat /sys/kernel/debug/tracing/stack_trace >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		fi
		if [ -e /proc/lock_stat ]; then
			echo file end :: /proc/lock_stat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
			cat /proc/lock_stat >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		fi

		# Mark the finish of the test
		echo test exit :: $TEST $EXIT_CODE
		echo test end :: $TEST `date +%s` >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		cat $SHELLPACK_LOG/timestamp-$RUNNAME >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
		rm $SHELLPACK_LOG/timestamp-$RUNNAME

		# Reset some parameters in case tests are sloppy
		hugeadm --pool-pages-min DEFAULT:0 2> /dev/null
		if [ "`lsmod | grep oprofile`" != "" ]; then
			opcontrol --stop   > /dev/null 2> /dev/null
			opcontrol --deinit > /dev/null 2> /dev/null
		fi

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
				mkdir -p /cgroups/$NR_TEST
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
stap-fix.sh --restore-only

if [ "$EXPANDED_VMLINUX" = "yes" ]; then
	echo Recompressing vmlinux
	gzip /boot/vmlinux-`uname -r`
fi

echo status :: $EXIT_CODE >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
exit $EXIT_CODE
