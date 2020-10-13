#!/bin/bash
# This script assumes the existence of a lot of supporting scripts
DEFAULT_CONFIG=config
DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
export PATH="$SCRIPTDIR/bin:$PATH:$SCRIPTDIR/bin-virt"
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh

MMTEST_PSSH_OPTIONS="$MMTEST_PSSH_OPTIONS -t 0 -O StrictHostKeyChecking=no"

if [ "$MARVIN_KVM_DOMAIN" = "" ]; then
	export MARVIN_KVM_DOMAIN="marvin-mmtests"
fi

usage() {
	echo "$0 [-pkoh] [-C CONFIG_HOST] [--vm VMNAME[,VMNAME][,...]] run-mmtests-options"
	echo
	echo "-h|--help              Prints this help."
	echo "-p|--performance       Force performance CPUFreq governor on the host before starting the tests"
	echo "-L|--host-logs         Collect logs and hardware info about the host"
	echo "-k|--keep-kernel       Use whatever kernel the VM currently has."
	echo "-o|--offline-iothreads Take down some VM's CPUs and use for IOthreads."
	echo "-C|--config-host CFG   Use CFG as config file for the host."
	echo "--vm VMNAME[,VMNAME]   Name(s) of existing, and already known to 'virsh', VM(s)."
	echo "                       If not specified, use \$MARVIN_KVM_DOMAIN as VM name."
	echo "                       If that is not defined, use 'marvin-mmtests'."
	echo "run-mmtests-options    Parameters for run-mmtests.sh inside the VM (check them"
	echo "                       with ./run-mmtests.sh -h)."
	echo ""
	echo "NOTE that 'run-mmtests-options', i.e., the parameters that will be used to execute"
	echo "run-mmtests.sh inside the VMs, must always follow all the parameters intended for"
	echo "run-kvm.sh itself."
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
declare -a CONFIGS
export CONFIGS
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
		-C|--config-host)
			shift
			CONFIGS+=( "$1" )
			shift
			;;
		--vm|--vms)
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

# We want to read the config(s) that run-mmtests.sh will use inside the guests.
# They are in the set of parameters that we have not parsed above, so retrieve
# them here, without "consuming" them.
declare -a MMTESTS_CONFIGS

for (( i=0; i < $#; i++ ))
do
	if [ "${!i}" = "-c" ] || [ "${!i}" = "--config" ]; then
		i=$((i+1))
		MMTESTS_CONFIGS+=( "${!i}" )
	fi
done

# No config file specified for guests, so they'll use the default.
[ ! -z $MMTESTS_CONFIGS ] || MMTESTS_CONFIGS=( "$DEFAULT_CONFIG" )

# If we have an host config, we use that one here. That's rather handy if,
# for instance, we want different monitors or topology related tuning
# on the host and in the guests.
#
# If, OTOH, we don't have an host config file, let's import the config
# file(s) of the guests and use them for the host as well.
[ ! -z $CONFIGS ] || CONFIGS=( "$DEFAULT_CONFIG" )

import_configs

# Command line has priority. However, if there wasn't any `--vm` param, check
# if we have a list of VMs to use in the config files. If there's nothing
# there either, default to $MARVIN_KVM_DOMAIN
if [ -z $VMS ] && [ "$MMTESTS_VMS" != "" ]; then
	VMS_LIST=yes
	# MMTESTS_VMS is space separated, we want VMS to be comma separated
	VMS=$(echo ${MMTESTS_VMS// /,})
fi
if [ -z $VMS ]; then
	VMS=$MARVIN_KVM_DOMAIN
fi

# If MMTESTS_HOST_IP is defined (e.g., in the configs we've imported), it
# means we are running as a "standalone virtualization bench suite". And we
# need to install some packages to be able to do so.
#
# We also need to check if, for instance, MMTESTS_HOST_IP is defined in
# whatever we are using as host config file. If it is, it must be there in
# the guests' configs as well, or we'll get stuck (because it's the fact
# that this var exists that tells guests that they need to contact the host
# for coordination of the test runs). So, we add it (and while there, add
# AUTO_PACKAGE_INSTALL too).
if [ ! -z $MMTESTS_HOST_IP ]; then
	install-depends pssh gnu_parallel expect netcat-openbsd

	for c in ${MMTESTS_CONFIGS[@]}; do
		if [ "`grep MMTESTS_HOST_IP ${c}`" = "" ] ; then
			echo "export MMTESTS_HOST_IP=${MMTESTS_HOST_IP}" >> ${c}
		fi
		if [ "`grep AUTO_PACKAGE_INSTALL ${c}`" = "" ] ; then
			echo "export AUTO_PACKAGE_INSTALL=\"yes\"" >> ${c}
		fi
	done
fi

install_numad
install_tuned

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

start_numad
start_tuned

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

# If $MMTESTS_PSSH_OUT_DIR contains a valid path, ask `pssh` to create there
# one file for each VM (name will be like root@<VM_IP>), were we can watch,
# live, the output of run-mmtests.sh, from inside each VM. This can be quite
# handy, especialy for debugging.
[ ! -z $MMTESTS_PSSH_OUTDIR ] && [ -d $MMTESTS_PSSH_OUTDIR ] && PSSH_OPTS="$PSSH_OPTS -o $MMTESTS_PSSH_OUTDIR"

teststate_log "vms ready :: `date +%s`"

echo Creating archive
NAME=`basename $SCRIPTDIR`
cd ..
tar -czf ${NAME}.tar.gz --exclude=${NAME}/work --exclude=${NAME}/.git ${NAME} || die Failed to create mmtests archive
mv ${NAME}.tar.gz ${NAME}/
cd ${NAME}

echo Uploading and extracting new mmtests
pscp $PSSH_OPTS ${NAME}.tar.gz ~ || die Failed to upload ${NAME}.tar.gz

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

pssh $PSSH_OPTS "cd git-private/$NAME && ./run-mmtests.sh $@" &
PSSHPID=$!

# This variable can be used to provide additional options to `nc`, as it is
# used both here and within the shellpacks. This is mostly intended for
# debugging, e.g., adding "-v" to have more output.
#export _NCV="-v"

# If MMTESTS_HOST_IP is defined, we need to coordinate run-mmtests.sh
# execution phases inside the various VMs.
#
# When each VM reach one of such phases, it will send a message, letting
# us know what state it has actually reached, and wait for a poke. What we
# need to do here, is making sure that all VMs have reached one state.
# As soon as we have collected as many tokens as there are VMs, it means
# we've reached that point, and we poke every VM so they can proceed.
#
# What the states are, and how transitioning between them occurs, is
# explained in the following diagram:
#
#  +-------+        +---------------+
#  | START +------->| mmtests_start |<-----+
#  +-------+        +-------+-------+      |
#                           |test_do/      |NO
#                           | tokens++     |
#                           v              |
#                 +-------------------+    |
#                 |tokens == VMCOUNT ?+----+
#                 +---------+---------+
#                           |YES/
#                           | tokens=0
#                           v
#                      +---------+
#            +-------->| test_do |<--------+
#            |         +----+----+         |
#            |              |test_do/      |
#            |              | tokens++     |NO
#            |              v              |
#   test_do/ |    +-------------------+    |
#    tokens=1|    |tokens == VMCOUNT ?+----+
#            |    +---------+---------+
#            |              |YES/
#            |              | tokens=0
#            |              v                mmtests_end/
#            +--------+-----------+           tokens=1
#      +------------->| test_do2  +----------------------+
#      |   +--------->+-----+-----+------------------+   |
#      |   |                |iteration_begin/        |   |
#      |   |                | tokens=1               |   |
#      |   |                v                        |   |
#      |   |       +-----------------+               |   |
#      |   |       | iteration_begin |<--------+     |   |
#      |   |       +--------+--------+         |     |   |
#      |   |                |iterations_begin/ |NO   |   |
#      |   |                | tokens++         |     |   |
#      |   |                v                  |     |   |
#      |   |      +-------------------+        |     |   |
#      |   |      |tokens == VMCOUNT ?+--------+     |   |
#      |   |      +---------+---------+              |   |
#      |   |                |YES/           test_done|   |
#      |   |                | tokens=0       tokens=1|   |
#      |   |                v                        |   |
#      |   |        +---------------+                |   |
#      |   |        | iteration_end |<--------+      |   |
#      |   |        +-------+-------+         |      |   |
#      |   |YES/            |iterations_end/  |NO    |   |
#      |   | tokens=0       | tokens++        |      |   |
#      |   |                v                 |      |   |
#      |   |      +-------------------+       |      |   |
#      |   +------+tokens == VMCOUNT ?+-------+      |   |
#      |          +-------------------+              |   |
#      |                                             |   |
#      |              +-----------+                  |   |
#      |              | test_done |<-----------------+   |
#      |              +-----+-----+<-------+             |
#      |YES/                |test_done/    |NO           |
#      | tokens=0           | tokens++     |             |
#      |                    v              |             |
#      |          +-------------------+    |             |
#      +----------+tokens == VMCOUNT ?+----+             |
#                 +-------------------+                  |
#                                                        |
#                    +-------------+<--------------------+
#                    | mmtests_end |<------+
#                    +------+------+       |
#                           |mmtests_end/  |
#                           | tokens++     |NO
#                           v              |
#  +-------+      +-------------------+    |
#  | QUIT  |<-----+tokens == VMCOUNT ?+----+
#  +-------+      +-------------------+
#
# For figuring out when VMs send the tokens for any give state,
# check run-mmtests.sh and the shellpacks rewriting code.
#
# Token exchanging happens (currently) over the network, via `nc`.
#
# TODO: likely, this can be re-implemented using, for instance, something
# like gRPC (either here, with https://github.com/fullstorydev/grpcurl) or
# by putting together some service program.
#
if [ ! -z $MMTESTS_HOST_IP ]; then
	echo $GUEST_IP
	STATE="mmtests_start"
	tokens=0
	NCFILE=`mktemp`
	nc $_NCV -n -4 -l -k $MMTESTS_HOST_IP $MMTESTS_HOST_PORT > $NCFILE &
	NCPID=$!
	tail -f $NCFILE | while [ "$STATE" != "QUIT" ] && read TOKEN
	do
		teststate_log "recvd token :: \"$TOKEN\" `date +%s`"
		# With only 1 VM, there is not much to be synched. We just need
		# to reply with the very same token we receive, in order to
		# unblock each phase of run-mmtests.sh, inside the VM itself.
		if [ $VMCOUNT -eq 1 ]; then
			case "$TOKEN" in
				"mmtests_start"|"test_do"|"iteration_begin"|"iteration_end"|"test_done")
					mmtests_signal_token "$TOKEN" ${GUEST_IP[@]}
					teststate_log "sent token :: \"$TOKEN\" `date +%s`"
					;;
				"mmtests_end")
					mmtests_signal_token "mmtests_end" ${GUEST_IP[@]}
					teststate_log "sent token :: \"$TOKEN\" `date +%s`"
					STATE="QUIT"
					;;
				*)
					echo "ERROR: unknown token (\'$TOKEN\') received!"
					STATE="QUIT"
					kill $PSSHPID
					;;
			esac
		else
			case "$STATE" in
				"mmtests_start"|"test_do"|"iteration_begin"|"iteration_end"|"test_done"|"mmtests_end")
					if [ $tokens -eq 0 ]; then
						# DEBUG: not very useful info to print, unless we're debugging
						#echo "run-kvm --> run-mmtests: state = $STATE"
						teststate_log "enter state :: \"$STATE\" `date +%s`"
						activity_log "run-kvm: state \"$STATE\""
					fi
					if [ "$TOKEN" != "$STATE" ]; then
						echo "ERROR: wrong toke (\'$TOKEN\') received while in state \'$STATE\'!"
						STATE="QUIT"
						kill $PSSHPID
					else
						tokens=$(( $tokens + 1 ))
					fi
					if [ $tokens -eq $VMCOUNT ]; then
						tokens=0
						if [ "$STATE" = "mmtests_start" ]; then
							STATE="test_do"
						elif [ "$STATE" = "test_do" ] || [ "$STATE" = "iteration_end" ] || [ $"$STATE" = "test_done" ]; then
							STATE="test_do2"
						elif [ "$STATE" = "iteration_begin" ]; then
							STATE="iteration_end"
						elif [ "$STATE" = "test_done" ]; then
							STATE="test_do2"
						elif [ "$STATE" = "mmtests_end" ]; then
							STATE="QUIT"
						fi
						activity_log "run-kvm: sending token \"$TOKEN\""
						mmtests_signal_token "$TOKEN" ${GUEST_IP[@]}
						teststate_log "sent token :: \"$TOKEN\" `date +%s`"
					fi
					;;
				"test_do2")
					tokens=1
					if [ "$TOKEN" = "test_do" ]; then
						STATE="test_do"
					elif [ "$TOKEN" = "test_done" ]; then
						STATE="test_done"
					elif [ "$TOKEN" = "iteration_begin" ]; then
						STATE="iteration_begin"
					elif [ "$TOKEN" = "mmtests_end" ]; then
						STATE="mmtests_end"
					else
						echo "ERROR: wrong toke (\'$TOKEN\') received while in state \'$STATE\'!"
						STATE="QUIT"
						kill $PSSHPID
					fi
					# DEBUG: not very useful info to print, unless we're debugging
					#echo "run-kvm --> run-mmtests: state = $STATE"
					teststate_log "enter state :: \"$STATE\" `date +%s`"
					activity_log "run-kvm: state \"$STATE\""
					;;
				*)
					echo "ERROR: unknown token (\'$TOKEN\') received!"
					STATE="QUIT"
					kill $PSSHPID
					;;
			esac
		fi
	done
	kill $NCPID
	rm -f $NCFILE
fi
wait $PSSHPID
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

shutdown_numad
shutdown_tuned

exit $RETVAL
