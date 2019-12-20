#!/bin/bash
# This script assumes the existence of a lot of supporting scripts
DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
export PATH="$PATH:$SCRIPTDIR/bin-virt"
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh

MMTEST_PSSH_OPTIONS="$MMTEST_PSSH_OPTIONS -t 0 -O StrictHostKeyChecking=no"

if [ "$MARVIN_KVM_DOMAIN" = "" ]; then
	export MARVIN_KVM_DOMAIN="marvin-mmtests"
fi

usage() {
	echo "$0 [-koh] [--vm VMNAME[,VMNAME][,...]] run-mmtests-options"
	echo
	echo "-h|--help              Prints this help."
	echo "-k|--keep-kernel       Use whatever kernel the VM currently has."
	echo "-o|--offline-iothreads Take down some VM's CPUs and use for IOthreads."
	echo "--vm VMNAME[,VMNAME]   Name(s) of existing, and already known to `virsh`, VM(s)."
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
			VMS_LIST="yes"
			VMS=$1
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

if [ -z $VMS ]; then
	VMS=$MARVIN_KVM_DOMAIN
fi

echo "Booting the VM(s)"
kvm-start --vm $VMS || die "Failed to boot VM(s)"

# Arrays where we store, for each VM, the IP and a VM-specific
# runname. The latter, in particular, is necessary because otherwise,
# when running the same benchmark in several VMs with different names,
# results would overwrite each other.
#
# NB: 'runname' is the last of our parameters, as it is the last
# parameter of run-mmtests.sh.
declare -a GUEST_IP
declare -a VM_RUNNAME
RUNNAME=${@:$#}
v=1
PREV_IFS=$IFS
IFS=,
for VM in $VMS; do
	GUEST_IP[$v]=`kvm-ip-address --vm $VM`
	PSSH_OPTS="$PSSH_OPTS -H root@${GUEST_IP[$v]}"
	VM_RUNNAME[$v]="$RUNNAME-$VM"
	v=$(( $v + 1 ))
done
IFS=$PREV_IFS
VMCOUNT=$(( $v - 1 ))
PSSH_OPTS="$PSSH_OPTS $MMTEST_PSSH_OPTIONS -p $(( $VMCOUNT * 2 ))"

echo Creating archive
NAME=`basename $SCRIPTDIR`
cd ..
tar -czf ${NAME}.tar.gz --exclude=${NAME}/work --exclude=${NAME}/.git ${NAME} || die Failed to create mmtests archive
mv ${NAME}.tar.gz ${NAME}/
cd ${NAME}

echo Uploading and extracting new mmtests
pscp $PSSH_OPTS ${NAME}.tar.gz . || die Failed to upload ${NAME}.tar.gz

pssh $PSSH_OPTS "mkdir -p git-private && rm -rf git-private/${NAME} && tar -C git-private -xf ${NAME}.tar.gz" || die Failed to extract ${NAME}.tar.gz
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
pssh $PSSH_OPTS "cd git-private/$NAME && ./run-mmtests.sh $@"
RETVAL=$?

echo Syncing $SHELLPACK_LOG_BASE_SUBDIR
IFS=,
v=1
for VM in $VMS; do
	# TODO: these two can probably be replaced with `pssh` and `pslurp`...
	ssh root@${GUEST_IP[$v]} "cd git-private/$NAME && tar -czf work-${VM_RUNNAME[$v]}.tar.gz $SHELLPACK_LOG_BASE_SUBDIR" || die Failed to archive $SHELLPACK_LOG_BASE_SUBDIR
	scp root@${GUEST_IP[$v]}:git-private/$NAME/work-${VM_RUNNAME[$v]}.tar.gz . || die Failed to download work.tar.gz
	# Do not change behavior, file names, etc, if no VM list is specified.
	# That, in fact, is how currently Marvin works, and we don't want to
	# break it.
	NEW_RUNNAME=$RUNNAME
	if [ "$VMS_LIST" = "yes" ]; then
		NEW_RUNNAME=${VM_RUNNAME[$v]}
	fi
	# Store the results of benchmark named `FOO`, done in VM 'bar' in
	# a directory called 'bar-FOO.
	tar --transform="s|$RUNNAME|$NEW_RUNNAME|" -xf work-${VM_RUNNAME[$v]}.tar.gz || die Failed to extract work.tar.gz
	v=$(( $v + 1 ))
done
IFS=$PREV_IFS

echo "Shutting down the VM(s)"
kvm-stop --vm $VMS

exit $RETVAL
