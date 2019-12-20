#!/bin/bash
# This script assumes the existence of a lot of supporting scripts
DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
export PATH="$PATH:$SCRIPTDIR/bin-virt"
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh

if [ "$MARVIN_KVM_DOMAIN" = "" ]; then
	export MARVIN_KVM_DOMAIN="marvin-mmtests"
fi

usage() {
	echo "$0 [-koh] [--vm VMNAME] run-mmtests-options"
	echo
	echo "-h|--help              Prints this help."
	echo "-k|--keep-kernel       Use whatever kernel the VM currently has."
	echo "-o|--offline-iothreads Take down some VM's CPUs and use for IOthreads."
	echo "--vm VMNAME            Use an existing VM known to \`virsh\` as VMNAME."
	echo "                       If not specified, use \$MARVIN_KVM_DOMAIN as VM name."
	echo "                       If that is not defined, use 'marvin-mmtests'."
	echo "run-mmtests-options    Parameters for run-mmtests.sh inside the VM."
}

# Parameters handling. Note that our own parmeters (i.e., run-kvm.sh
# parameters) must always come *before* the parameters we want MMTests
# inside the VM to use.
while true; do
	case "$1" in
		-k|--keep-kernel)
			KEEP_KERNEL="yes"
			shift
			;;
		-o|--offline-iothreads)
			OFFLINE_IOTHREADS="yes"
			shift
			;;
		--vm)
			shift
			VM=$1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			break
			;;
	esac
done

if [ -z $VM ]; then
	VM=$MARVIN_KVM_DOMAIN
else
	# Adjust the `runname` parameter to run-mmtests.sh to include (as
	# a suffix) the name of the VM. This way, we don't risk results
	# being overwritten (e.g., by a run of the same benchmark in a
	# VM with a different name).
	#
	# NB: This works because we know that 'runname' is the last of
	# our parameters, as it is the last parameter of run-mmtests.sh.
	RUNNAME=${@:$#}
	RUNNAME="$RUNNAME-$VM"
	set -- "${@:1:(($#-1))}" "$RUNNAME"
fi

echo Booting kvm instance
kvm-start --vm $VM || die Failed to boot KVM instance
GUEST_IP=`kvm-ip-address --vm $VM`

echo Creating archive
NAME=`basename $SCRIPTDIR`
cd ..
tar -czf ${NAME}.tar.gz --exclude=${NAME}/work --exclude=${NAME}/.git ${NAME} || die Failed to create mmtests archive
mv ${NAME}.tar.gz ${NAME}/
cd ${NAME}

echo Uploading and extracting new mmtests
scp ${NAME}.tar.gz root@$GUEST_IP: || die Failed to upload ${NAME}.tar.gz
ssh root@$GUEST_IP mkdir git-private
ssh root@$GUEST_IP rm -rf git-private/${NAME}
ssh root@$GUEST_IP tar -C git-private -xf ${NAME}.tar.gz || die Failed to extract ${NAME}.tar.gz
rm ${NAME}.tar.gz


if [ "$KEEP_KERNEL" != "yes" ]; then
	echo Booting current kernel `uname -r` $MORE_BOOT_ARGS on the guest
	kvm-boot `uname -r` $MORE_BOOT_ARGS || die Failed to boot `uname -r`
fi

if [ "$OFFLINE_IOTHREADS" = "yes" ]; then
	offline_cpus=`virsh dumpxml marvin-mmtests | grep -c iothreadpin`
	if [ "$offline_cpus" != "" ]; then
		echo Taking $offline_cpus offline for pinned io threads
		for PHYS_CPU in `virsh dumpxml marvin-mmtests | grep iothreadpin | sed -e "s/.* cpuset='\([0-9]\+\)'.*/\1/"`; do
			VIRT_CPU=`virsh dumpxml marvin-mmtests | grep vcpupin | grep "cpuset='$PHYS_CPU'" | sed -e "s/.* vcpu='\([0-9]\+\)'.*/\1/"`
			ssh root@$GUEST_IP "echo 0 > /sys/devices/system/cpu/cpu$VIRT_CPU/online"
			echo o Virt $VIRT_CPU phys $PHYS_CPU
		done
	fi
fi

echo Executing mmtests on the guest
ssh root@$GUEST_IP "cd git-private/$NAME && ./run-mmtests.sh $@"
RETVAL=$?

echo Syncing $SHELLPACK_LOG_BASE_SUBDIR
ssh root@$GUEST_IP "cd git-private/$NAME && tar -czf work.tar.gz $SHELLPACK_LOG_BASE_SUBDIR" || die Failed to archive $SHELLPACK_LOG_BASE_SUBDIR
scp root@$GUEST_IP:git-private/$NAME/work.tar.gz . || die Failed to download work.tar.gz
tar -xf work.tar.gz || die Failed to extract work.tar.gz

echo Shutting down kvm instance
kvm-stop --vm $VM

exit $RETVAL
