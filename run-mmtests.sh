#!/bin/bash
DEFAULT_CONFIG=config
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME" && pwd`
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

rm -f $SCRIPTDIR/bash_arrays # remove stale bash_arrays file
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/shellpacks/deferred-monitors.sh

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
		mkfs.$LOGDISK_FILESYSTEM $LOGDISK_MKFS_PARAM $LOGDISK_PARTITION
		if [ $? -ne 0 ]; then
			echo Forcing creating of filesystem if possible
			mkfs.$LOGDISK_FILESYSTEM -F $LOGDISK_MKFS_PARAM $LOGDISK_PARTITION || exit
		fi
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

# Force artificial date is requested
if [ "$MMTESTS_FORCE_DATE" != "" ]; then
	killall -STOP ntpd
	MMTESTS_FORCE_DATE_BASE=`date +%s`
	date -s "$MMTESTS_FORCE_DATE"
	MMTESTS_FORCE_DATE_START=`date +%s`
	echo Forcing reset of date: `date`
fi

# Install packages that are generally needed by a large number of tests
install-depends autoconf automake binutils-devel bzip2 dosfstools expect \
	expect-devel gcc gcc-32bit libhugetlbfs libtool make oprofile patch \
	recode systemtap xfsprogs xfsprogs-devel psmisc btrfsprogs xz wget \
	perl-Time-HiRes time tcl
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
		echo WARNING: Monitors enabled but none configured
	fi
fi

# Run tunings
echo Tuning the system before running: $RUNNAME
for T in $RUN_TUNINGS; do
	discover_script ./tunings/tuning-$T
	export TUNING_LOG=$SHELLPACK_LOG/$T-$RUNNAME-$TEST
	$EXPECT_UNBUFFER $DISCOVERED_SCRIPT > $TUNING_LOG || exit $SHELLPACK_ERROR
done

# Create RAID setup
if [ "$TESTDISK_RAID_DEVICES" != "" ]; then
	# Convert to megabytes
	TESTDISK_RAID_OFFSET=$((TESTDISK_RAID_OFFSET/1048576))
	TESTDISK_RAID_SIZE=$((TESTDISK_RAID_SIZE/1048576))

	RAID_CREATE_START=`date +%s`

	# Build the partition list
	NR_DEVICES=0
	SUBSET=
	for PART in $TESTDISK_RAID_DEVICES; do
		# Limit the TESTDISK_RAID_DEVICES for raid1
		if [ "$TESTDISK_RAID_TYPE" = "raid1" -a $NR_DEVICES -eq 2 ]; then
			continue
		fi
		if [ "$SUBSET" = "" ]; then
			SUBSET=$PART
		else
			SUBSET="$SUBSET $PART"
		fi
		NR_DEVICES=$((NR_DEVICES+1))
	done
	export TESTDISK_RAID_DEVICES=$SUBSET

	# Create expected list of partitions which may not exist yet
	TESTDISK_RAID_PARTITIONS=
	for DISK in $TESTDISK_RAID_DEVICES; do
		TESTDISK_RAID_PARTITIONS="$TESTDISK_RAID_PARTITIONS ${DISK}1"
	done

	# Record basic device information
	echo -n > $SHELLPACK_LOG/disk-raid-hdparm-$RUNNAME
	echo -n > $SHELLPACK_LOG/disk-raid-smartctl-$RUNNAME
	for DISK in $TESTDISK_RAID_DEVICES; do
		hdparm -I $DISK 2>&1 >> $SHELLPACK_LOG/disk-raid-hdparm-$RUNNAME
		smartctl -a $DISK 2>&1 >> $SHELLPACK_LOG/dks-raid-smartctl-$RUNNAME
	done

	# Check if a suitable device is already assembled
	echo Scanning and assembling existing devices: $TESTDISK_RAID_DEVICES
	mdadm --assemble --scan
	FULL_ASSEMBLY_REQUIRED=no
	LAST_MD_DEVICE=
	for DEVICE in $TESTDISK_RAID_DEVICES; do
		BASE_DEVICE=`basename $DEVICE`
		MD_DEVICE=`grep $BASE_DEVICE /proc/mdstat | sed -e 's/(auto-read-only)//' | awk '{print $1}'`
		if [ "$MD_DEVICE" = "" ]; then
			echo o Device $DEVICE is not part of a RAID array, assembly required
			FULL_ASSEMBLY_REQUIRED=yes
			continue
		fi

		if [ "$LAST_MD_DEVICE" = "" ]; then
			LAST_MD_DEVICE=$MD_DEVICE
		fi
		if [ "$LAST_MD_DEVICE" != "$MD_DEVICE" ]; then
			echo o Device $DEVICE is part of $MD_DEVICE which does not match $LAST_MD_DEVICE, assembly required
			FULL_ASSEMBLY_REQUIRED=yes
			continue
		fi

		PERSONALITY=`grep $BASE_DEVICE /proc/mdstat | awk '{print $4}'`
		if [ "$PERSONALITY" != "$TESTDISK_RAID_TYPE" ]; then
			echo o Device $DEVICE is part of a $PERSONALITY array instead of $TESTDISK_RAID_TYPE, assembly required
			FULL_ASSEMBLY_REQUIRED=yes
			continue
		fi
	done

	if [ "$FULL_ASSEMBLY_REQUIRED" = "yes" ]; then
		echo Full assembly required
		echo Creation start: `date`
		for DEVICE in $TESTDISK_RAID_DEVICES; do
			BASE_DEVICE=`basename $DEVICE`
			MD_DEVICE=`grep $BASE_DEVICE /proc/mdstat | awk '{print $1}'`

			if [ "$MD_DEVICE" != "" ]; then
				echo Cleaning up old device $MD_DEVICE
				vgremove -f mmtests-raid
				mdadm --remove $TESTDISK_RAID_MD_DEVICE
				mdadm --remove /dev/$MD_DEVICE
				mdadm --stop $TESTDISK_RAID_MD_DEVICE
				mdadm --stop /dev/$MD_DEVICE
				mdadm --remove $TESTDISK_RAID_MD_DEVICE
				mdadm --remove /dev/$MD_DEVICE
			fi
		done

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
		done

		echo Creating RAID device $TESTDISK_RAID_MD_DEVICE $TESTDISK_RAID_TYPE
		case $TESTDISK_RAID_TYPE in
		raid1)
			echo mdadm --create $TESTDISK_RAID_MD_DEVICE -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
			EXPECT_SCRIPT=`mktemp`
			cat > $EXPECT_SCRIPT <<EOF
spawn mdadm --create $TESTDISK_RAID_MD_DEVICE -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
expect {
	"Continue creating array?" { send yes\\r; exp_continue}
	"Wipe it"		   { send y\\r; exp_continue}
}
EOF
			expect -f $EXPECT_SCRIPT || exit -1
			rm $EXPECT_SCRIPT
			;;
		raid5)
			echo mdadm --create $TESTDISK_RAID_MD_DEVICE --bitmap=internal -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
			EXPECT_SCRIPT=`mktemp`
			cat > $EXPECT_SCRIPT <<EOF
spawn mdadm --create $TESTDISK_RAID_MD_DEVICE --bitmap=internal -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
expect {
	"Continue creating array?" { send yes\\r; exp_continue}
	"Wipe it"		   { send y\\r; exp_continue}
}
EOF
			expect -f $EXPECT_SCRIPT || exit -1
			rm $EXPECT_SCRIPT

			;;
		*)
			echo mdadm --create $TESTDISK_RAID_MD_DEVICE -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
			EXPECT_SCRIPT=`mktemp`
			cat > $EXPECT_SCRIPT <<EOF
spawn mdadm --create $TESTDISK_RAID_MD_DEVICE -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
expect {
	"Continue creating array?" { send yes\\r; exp_continue}
	"Wipe it"		   { send y\\r; exp_continue}
}
EOF
			expect -f $EXPECT_SCRIPT || exit -1
			rm $EXPECT_SCRIPT

			;;
		esac
	else
		echo Reusing existing raid configuration, removing old volume group
		vgremove -f mmtests-raid
	fi

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
	vgcreate mmtests-raid $TESTDISK_RAID_MD_DEVICE || exit
	SIZE=`vgdisplay mmtests-raid | grep Free | grep PE | awk '{print $5}'`
	if [ "$SIZE" = "" ]; then
		die Failed to determine LVM size
	fi
	lvcreate -l $SIZE mmtests-raid -n lvm0 || exit

	# Consider the test partition to be the LVM volume
	export TESTDISK_PARTITION=/dev/mmtests-raid/lvm0

	RAID_CREATE_END=`date +%s`
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

# Create storage cache device
if [ "${STORAGE_CACHE_TYPE}" = "dm-cache" ]; then
	if [ "${STORAGE_CACHING_DEVICE}" = "" -o \
		"${STORAGE_BACKING_DEVICE}" = "" ]; then
		echo "ERROR: no caching and/or backing device specified"
		exit 1
	fi
	if [ "${TESTDISK_FILESYSTEM}" != "" -a \
		"${TESTDISK_FILESYSTEM}" != "tmpfs" ]; then
		echo "Formatting test disk ${STORAGE_BACKING_DEVICE}:" \
		    " ${TESTDISK_FILESYSTEM}"
		mkfs.${TESTDISK_FILESYSTEM} ${TESTDISK_MKFS_PARAM} \
		    ${STORAGE_BACKING_DEVICE} || exit
		# quirk to prevent 2nd formatting of cache device
		TESTDISK_FILESYSTEM=""
	fi
	./bin/dmcache-setup.sh -c ${STORAGE_CACHING_DEVICE} \
	    -b ${STORAGE_BACKING_DEVICE} -a ||
	(echo "ERROR: dmcache-setup failed" \
	    "(dmcache-setup.sh -c ${STORAGE_CACHING_DEVICE}" \
	    "-b ${STORAGE_BACKING_DEVICE} -a)"; exit 1)
	TESTDISK_PARTITION=$(./dmcache-setup.sh -c ${STORAGE_CACHING_DEVICE} \
	    -b ${STORAGE_BACKING_DEVICE} --show-dev)
elif [ "${STORAGE_CACHE_TYPE}" = "bcache" ]; then
	install-depends bcache-tools
	if [ "${STORAGE_CACHING_DEVICE}" = "" -o \
		"${STORAGE_BACKING_DEVICE}" = "" ]; then
		echo "ERROR: no caching and/or backing device specified"
		exit 1
	fi
	./bin/bcache-setup.sh -c ${STORAGE_CACHING_DEVICE} \
	    -b ${STORAGE_BACKING_DEVICE} -r  ||
	(echo "ERROR: bcache-setup failed" \
	    "(bcache-setup.sh -c ${STORAGE_CACHING_DEVICE}" \
	    "-b ${STORAGE_BACKING_DEVICE} -r)"; exit 1)
	./bin/bcache-setup.sh -c ${STORAGE_CACHING_DEVICE} \
	    -b ${STORAGE_BACKING_DEVICE} -a ||
	(echo "ERROR: bcache-setup failed" \
	    "(bcache-setup.sh -c ${STORAGE_CACHING_DEVICE}" \
	    "-b ${STORAGE_BACKING_DEVICE} -a)"; exit 1)
	TESTDISK_PARTITION=$(./bin/bcache-setup.sh --show-dev \
	    -c ${STORAGE_CACHING_DEVICE} -b ${STORAGE_BACKING_DEVICE})
fi

# Create test disk(s)
if [ "$TESTDISK_PARTITION" != "" ]; then
	# override any TESTDISK_PARTITIONS configuration (for backwards compatibility)
	TESTDISK_PARTITIONS=($TESTDISK_PARTITION)
fi
# TBD: Support blktrace in case TESTDISK_PARTITIONS is set and TESTDISK_PARTITION is not
if [ ${#TESTDISK_PARTITIONS[*]} -gt 0 ]; then
	if [ "${STORAGE_CACHE_TYPE}" = "" ]; then
		hdparm -I ${TESTDISK_PARTITIONS[*]} 2>&1 > $SHELLPACK_LOG/disk-hdparm-$RUNNAME
	fi
	if [ "$TESTDISK_FILESYSTEM" != "" -a "$TESTDISK_FILESYSTEM" != "tmpfs" ]; then
		for i in ${!TESTDISK_PARTITIONS[*]}; do
			echo Formatting test disk ${TESTDISK_PARTITIONS[$i]}: $TESTDISK_FILESYSTEM
			mkfs.$TESTDISK_FILESYSTEM $TESTDISK_MKFS_PARAM ${TESTDISK_PARTITIONS[$i]} || exit
		done
	fi

	echo Mounting primary test disk
	if [ "$TESTDISK_MOUNT_ARGS" = "" ]; then
		if [ "$TESTDISK_FILESYSTEM" != "" ]; then
			mount -t $TESTDISK_FILESYSTEM $TESTDISK_PARTITIONS $SHELLPACK_TEST_MOUNT || exit
		else
			mount $TESTDISK_PARTITIONS $SHELLPACK_TEST_MOUNT || exit
		fi
	else
		if [ "$TESTDISK_FILESYSTEM" != "" ]; then
			mount -t $TESTDISK_FILESYSTEM $TESTDISK_PARTITIONS $SHELLPACK_TEST_MOUNT -o $TESTDISK_MOUNT_ARGS || exit
		else
			mount $TESTDISK_PARTITIONS $SHELLPACK_TEST_MOUNT -o $TESTDISK_MOUNT_ARGS || exit
		fi
	fi
	export TESTDISK_PRIMARY_SIZE_BYTES=`df $SHELLPACK_TEST_MOUNT | tail -1 | awk '{print $4}'`
	export TESTDISK_PRIMARY_SIZE_BYTES=$((TESTDISK_PRIMARY_SIZE_BYTES*1024))

	for i in ${!TESTDISK_PARTITIONS[*]}; do
		if [ "$TESTDISK_IO_SCHEDULER" != "" ]; then
			DEVICE=`basename ${TESTDISK_PARTITIONS[$i]}`
			START_DEVICE=$DEVICE
			while [ ! -e /sys/block/$DEVICE/queue/scheduler ]; do
				DEVICE=`echo $DEVICE | sed -e 's/.$//'`
				if [ "$DEVICE" = "" ]; then
					die "Unable to get an IO scheduler for $START_DEVICE"
				fi
			done
			echo $TESTDISK_IO_SCHEDULER > /sys/block/$DEVICE/queue/scheduler || die "Failed to set IO scheduler $TESTDISK_IO_SCHEDULER on /sys/block/$DEVICE/queue/scheduler"
			echo Set IO scheduler $TESTDISK_IO_SCHEDULER on $DEVICE
		fi

		if [ $i -eq 0 ]; then
			SHELLPACK_TEST_MOUNTS[$i]=$SHELLPACK_TEST_MOUNT
			echo Creating tmp and sources
			mkdir -p $SHELLPACK_SOURCES
			mkdir -p $SHELLPACK_TEMP
			continue
		fi
		SHELLPACK_TEST_MOUNTS[$i]=${SHELLPACK_TEST_MOUNT}_$i

		mkdir -p ${SHELLPACK_TEST_MOUNTS[$i]}
		echo Mounting additional test disk
		if [ "$TESTDISK_MOUNT_ARGS" = "" ]; then
			mount -t $TESTDISK_FILESYSTEM ${TESTDISK_PARTITIONS[$i]} ${SHELLPACK_TEST_MOUNTS[$i]} || exit
		else
			mount -t $TESTDISK_FILESYSTEM ${TESTDISK_PARTITIONS[$i]} ${SHELLPACK_TEST_MOUNTS[$i]} -o $TESTDISK_MOUNT_ARGS || exit
		fi

		echo "Creating tmp (${SHELLPACK_TEST_MOUNTS[$i]}/tmp/$$)"
		mkdir -p ${SHELLPACK_TEST_MOUNTS[$i]}/tmp/$$
	done
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
	if [ "$SHELLPACK_TEST_MOUNT" != "" -a ${#TESTDISK_PARTITIONS[*]} -gt 0 ]; then
		die "Can't use TESTDISK_PARTITION(S) together with TESTDISK_DIR"
	fi
	if ! [ -d "$TESTDISK_DIR" ]; then
		die "Can't find TESTDISK_DIR $TESTDISK_DIR"
	fi
	echo "Using directory $TESTDISK_DIR for test"
else
	if [ ${#SHELLPACK_TEST_MOUNTS[*]} -gt 0 -a ${#TESTDISK_PARTITIONS[*]} -gt 0 ]; then
		for i in ${!SHELLPACK_TEST_MOUNTS[*]}; do
			if [ $i -eq 0 ]; then
				TESTDISK_DIR="$SHELLPACK_TEMP"
				TESTDISK_DIRS[$i]="$SHELLPACK_TEMP"
			else
				TESTDISK_DIRS[$i]=${SHELLPACK_TEST_MOUNTS[$i]}/tmp/$$
			fi
			echo "Using ${TESTDISK_DIRS[$i]}"
		done
		export TESTDISK_DIRS
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

# Save bash arrays (marked as exported) to separate file. They are
# read-in via common.sh in subshells. This quirk is req'd as bash
# doesn't support export of arrays. Note that the file needs to be
# updated whenever an array is modified after this point.
# Currently required for:
# - TESTDISK_DIRS
declare -p | grep "\-ax" | tee $SCRIPTDIR/bash_arrays

# Warm up. More appropriate warmup depends on the exact test
if [ "$RUN_WARMUP" != "" ]; then
	echo Entering warmup
	RUNNING_TEST=$RUN_WARMUP
	./run-single-test.sh $RUN_WARMUP
	RUNNING_TEST=
	rm -rf $SHELLPACK_LOG/$RUN_WARMUP
	echo Warmup complete, beginning tests
else
	echo Skipping warmup run
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

export SHELLPACK_ACTIVITY="$SHELLPACK_LOG/tests-activity-$RUNNAME"
rm -f $SHELLPACK_ACTIVITY 2> /dev/null
echo `date +%s` run-mmtests: Start > $SHELLPACK_ACTIVITY

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
	ip addr show > $SHELLPACK_LOG/ip-addr-$RUNNAME
	echo start :: `date +%s` > $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	if [ "$RAID_CREATE_END" != "" ]; then
		echo raid-create :: $((RAID_CREATE_END-RAID_CREATE_START)) >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	fi
	echo arch :: `uname -m` >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	if [ "`which numactl 2> /dev/null`" != "" ]; then
		numactl --hardware >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
	fi
	PROC_FILES="/proc/vmstat /proc/zoneinfo /proc/meminfo /proc/schedstat"
	for TEST in $MMTESTS; do
		# Configure transparent hugepage support as configured
		reset_transhuge

		export CURRENT_TEST=$TEST
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

if [ "$MMTESTS_FORCE_DATE" != "" ]; then
	MMTESTS_FORCE_DATE_END=`date +%s`
	OFFSET=$((MMTESTS_FORCE_DATE_END-MMTESTS_FORCE_DATE_START))
	date -s "$(echo $((MMTESTS_FORCE_DATE_BASE+OFFSET)) | awk '{print strftime("%c", $0)}')"
	echo Restoring after forced date update: `date`
	killall -CONT ntpd
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

echo `date +%s` run-mmtests: End >> $SHELLPACK_ACTIVITY
echo status :: $EXIT_CODE >> $SHELLPACK_LOG/tests-timestamp-$RUNNAME
exit $EXIT_CODE
