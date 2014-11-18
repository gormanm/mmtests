#!/bin/bash

CONFIG=config
DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
. $SCRIPTDIR/$CONFIG
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SHELLPACK_TOPLEVEL/kvm.conf

if [ "$MMTESTS_KVM_IMAGEDIR" = "" ]; then
	echo No MMTESTS_KVM_IMAGEDIR
	exit -1
fi
if [ "$MMTESTS_KVM_DISKIMAGE" = "" ]; then
	echo No MMTESTS_KVM_DISKIMAGE
	exit -1
fi

cd $SHELLPACK_TOPLEVEL
QEMU_PID=`cat qemu.pid 2> /dev/null`
if [ "$QEMU_PID" != "" ]; then
	if [ "`ps -h --pid $QEMU_PID`" != "" ]; then
		echo QEMU pid $QEMU_PID already appears to be running
		exit -1
	fi
fi

# Download image if necessary
if [ ! -e $MMTESTS_KVM_IMAGEDIR/mmtests-root.img ]; then
	echo Downloading root image
	mkdir -p $MMTESTS_KVM_IMAGEDIR
	wget -O $MMTESTS_KVM_IMAGEDIR/mmtests-root.img $MMTESTS_KVM_DISKIMAGE
	if [ $? -ne 0 ]; then
		rm $MMTESTS_KVM_IMAGEDIR/mmtests-root.img
		echo Failed to download root image
		exit -1
	fi
fi

# Create swap image if necessary
if [ ! -e $MMTESTS_KVM_IMAGEDIR/mmtests-swap.img ]; then
	echo Creating swap image
	dd if=/dev/zero of=$MMTESTS_KVM_IMAGEDIR/mmtests-swap.img ibs=1048576 count=$((MMTESTS_KVM_SWAPSIZE/1048576))
	mkswap $MMTESTS_KVM_IMAGEDIR/mmtests-swap.img
fi

# Mount device for copying files
LOOP_DEVICE=`losetup -j $MMTESTS_KVM_IMAGEDIR/mmtests-root.img | head -1 | awk '{print $1}' | sed -e 's/://'`
if [ "$LOOP_DEVICE" = "" -o ! -e "$LOOP_DEVICE" ]; then
	losetup -fv $MMTESTS_KVM_IMAGEDIR/mmtests-root.img || exit -1
	LOOP_DEVICE=`losetup -j $MMTESTS_KVM_IMAGEDIR/mmtests-root.img | head -1 | awk '{print $1}' | sed -e 's/://'`
	if [ "$LOOP_DEVICE" = "" -o ! -e "$LOOP_DEVICE" ]; then
		echo Loop device \"$LOOP_DEVICE\" does not exist as expected
		exit -1
	fi
fi
echo Loop device: $LOOP_DEVICE
PART_DEVICE=/dev/mapper/`kpartx -av /dev/loop0 | head -1 | awk '{print $3}'`
if [ ! -e $PART_DEVICE ]; then
	sleep 5
	PART_DEVICE=/dev/mapper/`kpartx -av /dev/loop0 | head -1 | awk '{print $3}'`
	if [ ! -e $PART_DEVICE ]; then
		echo Partition device $PART_DEVICE does not exist as expected
		exit -1
	fi
fi
echo Part device: $PART_DEVICE
mkdir -p /tmp/mnt-mmtests
mount $PART_DEVICE /tmp/mnt-mmtests || exit -1

# Copy modules across if running a kernel
MODULES_DIRECTORY=/lib/modules
if [ ! -d $MODULES_DIRECTORY/$MMTESTS_KVM_KERNEL_VERSION ]; then
	if [ "$INSTALL_KERNEL_DESTINATION" != "" ]; then
		MODULES_DIRECTORY=$INSTALL_KERNEL_DESTINATION
	else
		MODULES_DIRECTORY=`pwd`/kernel-images
	fi
fi
if [ -d $MODULES_DIRECTORY/$MMTESTS_KVM_KERNEL_VERSION/ ]; then
	echo Copying modules across for $MMTESTS_KVM_KERNEL_VERSION
	if [ ! -d /tmp/mnt-mmtests/lib/modules ]; then
		echo Modules directory /tmp/mnt-mmtests/lib/modules does not exist as expected
		umount /tmp/mnt-mmtests
		exit -1
	fi

	if [ -e /tmp/mnt-mmtests/lib/modules/kvm-stale ]; then
		STALE=`cat /tmp/mnt-mmtests/lib/modules/kvm-stale`
		if [ "$STALE" != "" ]; then
			echo Removing /lib/modules/$STALE
			rm -rf /tmp/mnt-mmtests/lib/modules/$STALE
			if [ $? -ne 0 ]; then
				umount /tmp/mnt-mmtests
				exit -1
			fi
		fi
		rm /tmp/mnt-mmtests/lib/modules/kvm-stale
	fi
	echo Copying $MODULES_DIRECTORY/$MMTESTS_KVM_KERNEL_VERSION
	cp -r $MODULES_DIRECTORY/$MMTESTS_KVM_KERNEL_VERSION /tmp/mnt-mmtests/lib/modules
	echo $MMTESTS_KVM_KERNEL_VERSION > /tmp/mnt-mmtests/lib/modules/kvm-stale
else
	echo WARNING: modules directory $MODULES_DIRECTORY/$MMTESTS_KVM_KERNEL_VERSION does not exist
fi

# Copy mmtests across
echo Syncing to /tmp/mnt-mmtests/$SHELLPACK_TOPLEVEL
chmod a+x /tmp/mnt-mmtests/root
rm -rf /tmp/mnt-mmtests/$SHELLPACK_TOPLEVEL
mkdir -p /tmp/mnt-mmtests/$SHELLPACK_TOPLEVEL
rmdir /tmp/mnt-mmtests/$SHELLPACK_TOPLEVEL
echo 'kvm-images/' > /tmp/mmtests.exclude
echo 'work/' >> /tmp/mmtests.exclude
echo 'kernel-images/' >> /tmp/mmtests.exclude
rsync --exclude-from /tmp/mmtests.exclude -a $SHELLPACK_TOPLEVEL/ /tmp/mnt-mmtests/$SHELLPACK_TOPLEVEL
rm /tmp/mmtests.exclude

echo Unmounting KVM device
umount /tmp/mnt-mmtests
SANITY=`lsof $PART_DEVICE`
if [ "$SANITY" != "" ]; then
	echo Something still has $PART_DEVICE open, not safe
	exit -1
fi
dmsetup remove $PART_DEVICE
losetup -d $LOOP_DEVICE

NUMCPUS=$((NUMCPUS-4))
if [ $NUMCPUS -le 0 ]; then
	NUMCPUS=1
fi
if [ $NUMCPUS -ge 255 ]; then
	NUMCPUS=250
fi

# -redir tcp:30022::22							\
qemu-system-x86_64							\
-serial telnet:localhost:2000,server					\
-vnc :3									\
-no-reboot								\
-smp cpus=$NUMCPUS							\
-m $MMTESTS_KVM_MEMORY							\
-drive file=$MMTESTS_KVM_IMAGEDIR/mmtests-root.img,if=virtio,cache=none \
-drive file=$MMTESTS_KVM_IMAGEDIR/mmtests-swap.img,if=virtio,cache=none \
-no-reboot								\
-s 									\
--enable-kvm								\
-net nic,model=rtl8139							\
-net user,hostfwd=tcp::30022-:22					\
-kernel $MMTESTS_KVM_KERNEL						\
-initrd $MMTESTS_KVM_INITRD						\
-append "$MMTESTS_KVM_APPEND"						\
$@ &
QEMU_PID=$!
echo $QEMU_PID > $SHELLPACK_TOPLEVEL/qemu.pid

sleep 5
if [ "$MMTESTS_KVM_FOREGROUND" = "yes" ]; then
	telnet localhost 2000
else
	if [ "$MMTESTS_KVM_SERIAL_VISIBLE" = "yes" ]; then
		telnet localhost 2000 | tee kvm-console.log &
	else
		telnet localhost 2000 > kvm-console.log &
	fi

	echo Waiting on KVM instance $QEMU_PID to reach ssh
	wait_ssh_available localhost 30022
fi
exit $?
