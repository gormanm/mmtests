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

qemu-system-x86_64							\
-serial telnet:localhost:2000,server					\
-redir tcp:30022::22							\
-m $MMTESTS_KVM_MEMORY							\
-drive file=$MMTESTS_KVM_IMAGEDIR/mmtests-root.img,if=virtio,cache=none \
-drive file=$MMTESTS_KVM_IMAGEDIR/mmtests-swap.img,if=virtio,cache=none \
-no-reboot								\
-s 									\
--enable-kvm								\
-net nic,model=rtl8139							\
-net user								\
$@ &
QEMU_PID=$!
echo $QEMU_PID > $SHELLPACK_TOPLEVEL/qemu.pid

sleep 5
if [ "$MMTESTS_KVM_SERIAL_VISIBLE" = "yes" ]; then
	telnet localhost 2000 | tee kvm-console.log &
else
	telnet localhost 2000 > kvm-console.log &
fi

echo Waiting on PID $QEMU_PID
wait $QEMU_PID

#-kernel $MMTESTS_KVM_KERNEL						\
#-initrd $MMTESTS_KVM_INITRD						\
#-append "earlyprintk=serial,ttyS0 root=/dev/hda1 console=tty0 console=ttyS0 loglevel=9"			\
