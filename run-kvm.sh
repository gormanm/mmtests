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
	echo "$0 [-pkoh] [--vm VMNAME[,VMNAME][,...]] run-mmtests-options"
	echo
	echo "-h|--help              Prints this help."
	echo "-p|--performance       Force performance CPUFreq governor on the host before starting the tests"
	echo "-L|--host-logs         Collect logs and hardware info about the host"
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
#
# There may be params that are valid arguments for both run-kvm.sh and
# run-mmtests.sh. We need to make sure that they are parsed only once.
# In fact, if we any of them is actually present twice, and we parse both
# the occurrences in here, then run-mmtests.sh, when run inside the VMs(s),
# will not see them.
#
# This is why this code looks different than "traditional" parameter handling,
# but it is either this, or we mandate that there can't be parameters with the
# same names in run-kvm.sh and run-mmtests.sh.
while true; do
	case "$1" in
		-p|--performance)
			if [ -z $FORCE_HOST_PERFORMANCE_SETUP ]; then
				export FORCE_HOST_PERFORMANCE_SETUP="yes"
				shift
			else
				break
			fi
			;;
		-L|--host-logs)
			HOST_LOGS="yes"
			shift
			;;
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

# NB: 'runname' is the last of our parameters, as it is the last
# parameter of run-mmtests.sh.
declare -a GUEST_IP
declare -a VM_RUNNAME
RUNNAME=${@:$#}

# We only collect logs if the '-L' parameter was present.
if [ "$HOST_LOGS" = "yes" ]; then
	export SHELLPACK_LOG=$SHELLPACK_LOG_BASE/$RUNNAME-host
	# Delete old runs
	rm -rf $SHELLPACK_LOG &>/dev/null
	mkdir -p $SHELLPACK_LOG
	export SHELLPACK_ACTIVITY="$SHELLPACK_LOG/tests-activity"
	export SHELLPACK_LOGFILE="$SHELLPACK_LOG/tests-timestamp"
	export SHELLPACK_SYSSTATEFILE="$SHELLPACK_LOG/tests-sysstate"
	rm -f $SHELLPACK_ACTIVITY $SHELLPACK_LOGFILE $SHELLPACK_SYSSTATEFILE
fi

teststate_log "start :: `date +%s`"

echo "Booting the VM(s)"
activity_log "run-kvm: Booting VMs"
kvm-start --vm $VMS || die "Failed to boot VM(s)"

teststate_log "VMs up :: `date +%s`"

# Arrays where we store, for each VM, the IP and a VM-specific
# runname. The latter, in particular, is necessary because otherwise,
# when running the same benchmark in several VMs with different names,
# results would overwrite each other.
v=1
PREV_IFS=$IFS
IFS=,
for VM in $VMS; do
	GUEST_IP[$v]=`kvm-ip-address --vm $VM`
	echo "VM ready: $VM IP: ${GUEST_IP[$v]}"
	activity_log "run-kvm: VM $VM IP ${GUEST_IP[$v]}"
	PSSH_OPTS="$PSSH_OPTS -H root@${GUEST_IP[$v]}"
	if [ "$HOST_LOGS" = "yes" ]; then
		virsh dumpxml $VM > $SHELLPACK_LOG/$VM.xml
	fi
	VM_RUNNAME[$v]="$RUNNAME-$VM"
	v=$(( $v + 1 ))
done
IFS=$PREV_IFS
VMCOUNT=$(( $v - 1 ))
PSSH_OPTS="$PSSH_OPTS $MMTEST_PSSH_OPTIONS -p $(( $VMCOUNT * 2 ))"

teststate_log "vms ready :: `date +%s`"

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

# Set performance governor on the host, if wanted
if [ "$FORCE_HOST_PERFORMANCE_SETUP" = "yes" ]; then
	FORCE_HOST_PERFORMANCE_SCALINGGOV_BASE=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
	NOTURBO="/sys/devices/system/cpu/intel_pstate/no_turbo"
	[ -f $NOTURBO ] && FORCE_HOST_PERFORMANCE_NOTURBO_BASE=`cat $NOTURBO`
	force_performance_setup
fi

sysstate_log_basic_info
collect_hardware_info
collect_kernel_info
collect_sysconfig_info

echo Executing mmtests on the guest
activity_log "run-kvm: begin run-mmtests in VMs"
teststate_log "test begin :: `date +%s`"

sysstate_log_proc_files "start"

pssh $PSSH_OPTS "cd git-private/$NAME && ./run-mmtests.sh $@"
RETVAL=$?

sysstate_log_proc_files "end"

teststate_log "test end :: `date +%s`"
activity_log "run-kvm: run-mmtests in VMs end"

if [ "$FORCE_HOST_PERFORMANCE_SETUP" = "yes" ]; then
	restore_performance_setup $FORCE_HOST_PERFORMANCE_SCALINGGOV_BASE $FORCE_HOST_PERFORMANCE_NOTURBO_BASE
fi

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
activity_log "run-kvm: Shutoff VMs"
kvm-stop --vm $VMS
teststate_log "VMs down :: `date +%s`"

teststate_log "finish :: `date +%s`"
teststate_log "status :: $RETVAL"

if [ "$HOST_LOGS" = "yes" ]; then
	dmesg > $SHELLPACK_LOG/dmesg
	gzip -f $SHELLPACK_LOG/dmesg
	gzip -f $SHELLPACK_SYSSTATEFILE
fi

exit $RETVAL
