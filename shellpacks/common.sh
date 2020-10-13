if [ -e $SCRIPTDIR/bash_arrays ]; then
	. $SCRIPTDIR/bash_arrays
fi
export SHELLPACK_ERROR=-1
export SHELLPACK_FAILURE=-1
export SHELLPACK_SUCCESS=0
if [ "$SCRIPTDIR" = "" ]; then
	echo $P: SCRIPTDIR not set, should not happen
	exit $SHELLPACK_ERROR
fi

# Default (i.e., in case they are not specified in the config files,
# or already defined in the environment) host and guest data exchange ports,
# for the benchmark synch protocol.
export MMTESTS_HOST_PORT=${MMTESTS_HOST_PORT:-1234}
export MMTESTS_GUEST_PORT=${MMTESTS_GUEST_PORT:-4321}

MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
NUMCPUS=$(grep -c '^processor' /proc/cpuinfo)
NUMNODES=`grep ^Node /proc/zoneinfo | awk '{print $2}' | sort | uniq | wc -l`
LLC_INDEX=`find /sys/devices/system/cpu/ -type d -name "index*" | sed -e 's/.*index//' | sort -n | tail -1`
NUMLLCS=`grep . /sys/devices/system/cpu/cpu*/cache/index$LLC_INDEX/shared_cpu_map | awk -F : '{print $NF}' | sort | uniq | wc -l`

WGET_SHOW_PROGRESS="--show-progress --progress=bar:force:noscroll"
wget --help | grep -q show-progress
if [ $? -ne 0 ]; then
	WGET_SHOW_PROGRESS=
fi

grep -q nosmt /proc/cmdline
if [ $? -eq 0 ]; then
	echo WARNING: Artifically boosting NUMCPUS to account for nosmt comparison
	NUMCPUS=$((NUMCPUS*2))
fi

export MMTESTS_LIBDIR="lib"
LONG_BIT=`getconf LONG_BIT`
if [ "$LONG_BIT" = "64" ]; then
	export MMTESTS_LIBDIR="lib64"
fi

function die() {
	rm -rf $SHELLPACK_TEMP
	if [ "$P" != "" ]; then
		TAG=" $P"
	fi
	echo "FATAL${TAG}: $@"
	exit $SHELLPACK_ERROR
}

function error() {
	if [ "$P" != "" ]; then
		TAG=" $P"
	fi
	echo "ERROR${TAG}: $@"
}

function warn() {
	if [ "$P" != "" ]; then
		TAG=" $P"
	fi
	echo "WARNING${TAG}: $@"
}

function import_configs() {
	for ((i = 0; i < ${#CONFIGS[@]}; i++ )); do
		if [ ! -e "${CONFIGS[$i]}" ]; then
			echo "A config must be in the current directory or specified with --config"
			echo "File ${CONFIGS[$i]} not found"
			exit -1
		fi
	done
	for ((i = 0; i < ${#CONFIGS[@]}; i++ )); do
		source "${CONFIGS[$i]}"
	done
}

function wait_on_pid_start() {
	WAITPID=$1
	ABORTTIME=$2

	if [ "$ABORTTIME" = "" ]; then
		ABORTTIME=0
	fi

	if [ "$WAITPID" != "" ]; then
		echo -n Waiting on pid $WAITPID to start
		SLEPT=0
		while [ "`ps h --pid $WAITPID`" = "" ]; do
			echo -n .
			sleep 1
			SLEPT=$((SLEPT+1))
			if [ $ABORTTIME -gt 0 -a $SLEPT -gt $ABORTTIME ]; then
				echo WARNING: Pid wait timeout
				return 1
			fi
		done
		echo
	fi
	return 0
}


function wait_on_pid_exit() {
	WAITPID=$1
	ABORTTIME=$2

	if [ "$ABORTTIME" = "" ]; then
		ABORTTIME=0
	fi

	if [ "$WAITPID" != "" ]; then
		echo -n Waiting on pid $WAITPID to shutdown
		SLEPT=0
		while [ "`ps h --pid $WAITPID`" != "" ]; do
			echo -n .
			sleep 1
			SLEPT=$((SLEPT+1))
			if [ $ABORTTIME -gt 0 -a $SLEPT -gt $ABORTTIME ]; then
				echo WARNING: Pid wait timeout
				return 1
			fi
		done
		echo
	fi
	return 0
}

function wait_on_pid_file() {
	PIDFILE=$1
	TIMEOUT=$2

	sleep 1
	ATTEMPT=1
	echo -n "Waiting on pidfile \"`basename $PIDFILE`\" "
	while [ ! -e $PIDFILE ]; do
		echo -n O
		sleep 1
		if [ "$TIMEOUT" != "" ]; then
			ATTEMPT=$((ATTEMPT+1))
			if [ $ATTEMPT -gt $TIMEOUT ]; then
				echo Pidfile failed to appear within timeout
				exit $SHELLPACK_ERROR
			fi
		fi
	done

	PIDWAIT=`cat $PIDFILE | head -1`
	while [ "$PIDWAIT" = "" ]; do
		echo -n o
		sleep 1
		PIDWAIT=`cat $PIDFILE`
	done

	while [ "`ps h --pid $PIDWAIT 2>/dev/null`" = "" ]; do
		echo -n .
		sleep 1
		PIDWAIT=`cat $PIDFILE`
	done
	echo
}

function shutdown_pid() {
	TITLE=$1
	SHUTDOWN_PID=$2
	if [ "$TITLE" = "" -o "$SHUTDOWN_PID" = "" ]; then
		error Did not specify name and PID to shutdown
	fi

	echo -n Shutting down $TITLE pid $SHUTDOWN_PID
	ATTEMPT=0
	kill $SHUTDOWN_PID
	while [ "`ps h --pid $SHUTDOWN_PID`" != "" ]; do
		echo -n .
		sleep 1
		ATTEMPT=$((ATTEMPT+1))
		if [ $ATTEMPT -gt 5 ]; then
			kill -9 $SHUTDOWN_PID
		fi
	done
	echo
}

function install_tuned() {
	install-depends tuned

	if [ `which tuned 2>/dev/null` = "" ]; then
		die tuned requested but unavailable
	fi
	mkdir -p /var/log/tuned
}

function start_tuned() {
	local answ=""

	if [ "$MMTESTS_TUNED_PROFILE" = "" ]; then
		return
	fi
	echo Restarting tuned and purge log. Will use $MMTESTS_TUNED_PROFILE as profile
	killall -KILL tuned
	rm -f /var/log/tuned/tuned.log
	local TUNEDOUT_TEMP=`mktemp`
	tuned --profile $MMTESTS_TUNED_PROFILE -l /var/log/tuned/tuned.log &> $TUNEDOUT_TEMP &
	export TUNED_PID=$!
	echo -n Waiting on tuned.log
	while [ ! -e /var/log/tuned/tuned.log ]; do
		echo .
		sleep 1
	done
	echo
	echo tuned started: pid $TUNED_PID
	tuned-adm profile &>> $TUNEDOUT_TEMP

	# Since some profile require reboot, let's double check. And let's
	# also give the user a chance to bail, if it failed.
	tuned-adm verify &>> $TUNEDOUT_TEMP
	if [ $? -ne 0 ]; then
		echo "WARNING: Errors applying profile: $MMTESTS_TUNED_PROFILE"
		echo "Do you wish to continue anyway (y/n, default y, timeout 10 sec)?"
		read -t 10 -n 1 answ
		[ $? -eq 0 ] && [ "$answ" = "n" ] && exit 1
	fi
	if [ ! -z $SHELLPACK_LOG ]; then
		cat $TUNEDOUT_TEMP >> $SHELLPACK_LOG/tuned-stdout
	fi
}

function shutdown_tuned() {
	if [ -z $TUNED_PID ]; then
		return
	fi
	echo Shutting down tuned pid $TUNED_PID
	kill $TUNED_PID
	sleep 10
	if [ ! -z $SHELLPACK_LOG ]; then
		mv /var/log/tuned/tuned.log $SHELLPACK_LOG/tuned-log
	fi
}

function install_numad() {
	if [ "$MMTESTS_NUMA_POLICY" != "numad" ]; then
		return
	fi
	install-depends numad
	if [ `which numad 2>/dev/null` = "" ]; then
		die numad requested but unavailable
	fi
}

function start_numad() {
	if [ "$MMTESTS_NUMA_POLICY" != "numad" ]; then
		return
	fi
	echo Restart numad and purge log as per MMTESTS_NUMA_POLICY
	killall -KILL numad
	rm -f /var/log/numad.log
	NUMADOUT_TEMP=`mktemp`
	numad -F -d &> $NUMADOUT_TEMP &
	export NUMAD_PID=$!
	echo -n Waiting on numad.log
	while [ ! -e /var/log/numad.log ]; do
		echo .
		sleep 1
	done
	echo
	if [ ! -z $SHELLPACK_LOG ]; then
		cp $NUMADOUT_TEMP $SHELLPACK_LOG/numad-stdout
	fi
	echo Numad started: pid $NUMAD_PID
}

function shutdown_numad() {
	if [ -z $NUMAD_PID ]; then
		return;
	fi
	echo Shutting down numad pid $NUMAD_PID
	kill $NUMAD_PID
	sleep 10
	if [ ! -z $SHELLPACK_LOG ]; then
		mv /var/log/numad.log $SHELLPACK_LOG/numad-log
	fi
}

function fixup_stap() {
	install-depends systemtap
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
}

function check_status() {
	EXITCODE=$?

	if [ $EXITCODE != 0 ]; then
		echo "FATAL: $@"
		rm -rf $SHELLPACK_TEMP
		exit $SHELLPACK_ERROR
	fi

	echo $1 fine
}

function save_rc() {
	"$@"
	echo $? > "/tmp/shellpack-rc.$$"
}

function recover_rc() {
	EXIT_CODE=`cat /tmp/shellpack-rc.$$`
	rm -f /tmp/shellpack-rc.$$
	( exit $EXIT_CODE )
}

# Optionally create a mirror on the testdisk. This is necessary when
# the tarballs are too large to fit on the test partition after expansion.
# It assumes that a mirror is no more than one directory deep
function update_local_mirror() {
	MIRROR=$1

	if [ "$MIRROR_LOCATION" = "" ]; then
		return
	fi
	if [ "$MMTESTS_CREATE_MIRROR" != "yes" ]; then
		return
	fi

	WEBROOT_ESCAPED=`echo "$WEBROOT" | sed -e 's/\//\\\\\//g'`
	MIRROR=`echo $MIRROR | sed -e "s/$WEBROOT_ESCAPED//" -e 's/^\/*//' -e 's/\/\//\//g'`
	MIRROR_FILE=`basename $MIRROR`
	MIRROR_DIR=`echo $MIRROR | sed -e "s/\/$MIRROR_FILE$//"`

	if [ ! -e $SHELLPACK_SOURCES/$MIRROR_FILE ]; then
		return
	fi

	if [ "$MIRROR_ON_TESTDISK" = "yes" ]; then
		mkdir -p $SHELLPACK_TEST_MOUNT/mirror
		rm -f $SHELLPACK_LOCAL_MIRROR
		if [ -e $SHELLPACK_LOCAL_MIRROR ]; then
			die "Unexpected trailing mirror"
		fi
		ln -s $SHELLPACK_TEST_MOUNT/mirror $SHELLPACK_LOCAL_MIRROR
	else
		mkdir -p $SHELLPACK_LOCAL_MIRROR
	fi

	mkdir -p $SHELLPACK_LOCAL_MIRROR/$MIRROR_DIR
	mv $SHELLPACK_SOURCES/$MIRROR_FILE $SHELLPACK_LOCAL_MIRROR/$MIRROR_DIR || die "Failed to move $MIRROR_FILE to mirror"
	ln -s $SHELLPACK_LOCAL_MIRROR/$MIRROR $SHELLPACK_SOURCES/$MIRROR_FILE || die "Failed to symbolic link to sources"
}

function file_fetch() {
	WEB=$1
	MIRROR=$2
	OUTPUT=$3

	if [ -s $OUTPUT ]; then
		echo Downloaded file already available at $OUTPUT
		return
	fi
	rm -f $OUTPUT

	if [ "$MMTESTS_IGNORE_MIRROR" != "yes" ]; then
		echo "$P: Fetching from mirror $MIRROR"
		wget -q $WGET_SHOW_PROGRESS -O $OUTPUT $MIRROR
	fi
	if [ "$MMTESTS_IGNORE_MIRROR" = "yes" -o $? -ne 0 ]; then
		if [ "$WEB" = "NOT_AVAILABLE" ]; then
			die "Benchmark is not publicly available. You must make it available from a local mirror"
		fi

		echo "$P: Fetching from internet $WEB"
		wget -q $WGET_SHOW_PROGRESS -O $OUTPUT $WEB
		if [ $? -ne 0 ]; then
			die "$P: Could not download $WEB"
		fi
	fi
	update_local_mirror $MIRROR
}

function sources_fetch() {
	WEB=$1
	MIRROR=$2
	OUTPUT=$3
	WEB_ALT=$4

	if [ -s $OUTPUT ]; then
		echo Downloaded file already available at $OUTPUT
		return
	fi
	rm -f $OUTPUT

	if [ "$MMTESTS_IGNORE_MIRROR" != "yes" ]; then
		echo "$P: Fetching from mirror $MIRROR"
		wget -q $WGET_SHOW_PROGRESS -O $OUTPUT $MIRROR
	fi
	if [ "$MMTESTS_IGNORE_MIRROR" = "yes" -o $? -ne 0 ]; then
		if [ "$WEB" = "NOT_AVAILABLE" ]; then
			die "Benchmark is not publicly available. You must make it available from a local mirror"
		fi

		echo "$P: Fetching from internet $WEB"
		wget -q $WGET_SHOW_PROGRESS -O $OUTPUT $WEB
		if [ $? -ne 0 ]; then
			if [ "$WEB_ALT" = "" ]; then
				die "$P: Could not download $WEB"
			fi
			echo "$P: Fetching from alt internet $WEB_ALT"
			wget -q $WGET_SHOW_PROGRESS -O $OUTPUT $WEB_ALT
			if [ $? -ne 0 ]; then
				die "$P: Could not download $WEB_ALT"
			fi
		fi
	fi
	update_local_mirror $MIRROR
}

function git_commit_exists() {
	git show $1 >/dev/null 2>&1
	echo $?
}

function git_fetch() {
	GIT=$1
	TREE=$2
	MIRROR=$3
	OUTPUT=$4
	COMMIT=${5:-master}

	if [ -s $OUTPUT ]; then
		echo Downloaded file already available at $OUTPUT
		return
	fi

	if [ $COMMIT = "0" ]; then
		COMMIT=master
	fi

	install-depends git-core

	if [ "$MMTESTS_IGNORE_MIRROR" != "yes" ]; then
		echo "$P: Fetching from mirror $MIRROR"
		wget -q $WGET_SHOW_PROGRESS -O $OUTPUT $MIRROR
	fi

	if [ "$MMTESTS_IGNORE_MIRROR" = "yes" -o $? -ne 0 ]; then
		if [ "$GIT" = "NOT_AVAILABLE" ]; then
			die Benchmark is not publicly available. You must make it available from a local mirror
		fi

		cd $SHELLPACK_SOURCES
		echo "$P: Cloning from internet $GIT"
		git clone $GIT_CLONE_FLAGS $GIT $TREE
		if [ $? -ne 0 ]; then
			die "$P: Could not clone $GIT"
		fi
		cd $TREE || die "$P: Could not cd $TREE"
		if [ $(git_commit_exists $COMMIT) != 0 ]; then
			echo "$P: $COMMIT is not a tag/commit. Fetching master"
			COMMIT=master
		fi
		git checkout $COMMIT
		echo Creating $OUTPUT
		git archive --format=tar --prefix=$TREE/ $COMMIT | gzip -c > $OUTPUT
		cd -
	fi

	update_local_mirror $MIRROR
}

function hg_fetch() {
	HG=$1
	TREE=$2
	MIRROR=$3
	OUTPUT=$4

	install-depends mercurial

	echo "$P: Fetching from mirror $MIRROR"
	wget -q $WGET_SHOW_PROGRESS -O $OUTPUT $MIRROR
	if [ $? -ne 0 ]; then
		if [ "$HG" = "NOT_AVAILABLE" ]; then
			die Benchmark is not publicly available. You must make it available from a local mirror
		fi

		cd $SHELLPACK_SOURCES
		echo "$P: Cloning from internet $HG"
		hg clone $HG $TREE
		if [ $? -ne 0 ]; then
			die "$P: Could not clone $HG"
		fi
		cd $TREE || die "$P: Could not cd $TREE"
		echo Creating $OUTPUT
		BASENAME=`basename $OUTPUT .gz`
		hg archive --type tar --prefix=$TREE/ $BASENAME
		gzip -f $BASENAME
		mv $BASENAME.gz $OUTPUT
		cd -
	fi

}

export TRANSHUGE_AVAILABLE=no
if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
	export TRANSHUGE_AVAILABLE=yes
	export TRANSHUGE_DEFAULT=`cat /sys/kernel/mm/transparent_hugepage/enabled | awk -F [ '{print $2}' | awk -F ] '{print $1}'`
fi

function enable_transhuge() {
	if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo always > /sys/kernel/mm/transparent_hugepage/enabled
	fi
}

function disable_transhuge() {
	if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo never > /sys/kernel/mm/transparent_hugepage/enabled
	fi
}

function reset_transhuge() {
	if [ "$VM_TRANSPARENT_HUGEPAGES_DEFAULT" = "" ]; then
		VM_TRANSPARENT_HUGEPAGES_DEFAULT=default
	fi
	if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
		if [ "$VM_TRANSPARENT_HUGEPAGES_DEFAULT" = "default" ]; then
			echo $TRANSHUGE_DEFAULT > /sys/kernel/mm/transparent_hugepage/enabled
		else
			echo $VM_TRANSPARENT_HUGEPAGES_DEFAULT > /sys/kernel/mm/transparent_hugepage/enabled
		fi
	else
		if [ "$VM_TRANSPARENT_HUGEPAGES_DEFAULT" != "never" -a "$VM_TRANSPARENT_HUGEPAGES_DEFAULT" != "default" ]; then
			echo Tests configured to use THP but it is unavailable
			exit
		fi
	fi
}

function mmtests_activity() {
	if [ "$SHELLPACK_ACTIVITY" != "" -a -f "$SHELLPACK_ACTIVITY" ]; then
		NAME=
		if [ "$P" = "" ]; then
			NAME=$0
		else
			NAME=$P
		fi
		echo `date +%s` $NAME: $@ >> $SHELLPACK_ACTIVITY
	fi
}

# Benchmarking synchronization utility functions.
#
# Basically, from run-mmtests.sh we send tokens to a certain IP:PORT,
# to let the "controller" know that a certain state has been reached.
# Similarly, we may want to wait for a specific token from the controller,
# before proceeding any further.
#
# Communication happens with `nc`, and we try to make sure that the
# controller is listening, that the connection can be established, etc.,
# before actually sending (for minimizing the probability of tokens getting
# lost).
#
# TODO: likely, this can be re-implemented using, for instance, something
# like gRPC (either here, with https://github.com/fullstorydev/grpcurl) or
# by putting together some service program.

# Send a token to IP:PORT. Before actually sending, we wait for the
# destination to be ready and accepting connections.
#
# $1: target IP
# $2: target port
# $3: token
function mmtests_send_token() {
	while :
	do
		nc $_NCV -4 -z $1 $2
		if [ $? -eq 0 ]; then
			# Connection can be established, let's send!
			echo "$3" | nc $_NCV -n -4 -q 0 $1 $2
			if [ $? -eq 0 ]; then
				break
			fi
		else
			sleep 1
		fi
	done
}

# Wait for a token on a PORT.
#
# $1: receiving port
# $2: if present, the token we will wait for.
#     If not present, any token received will break the loop.
function mmtests_recv_token() {
	PORT=$1
	local TOK=""
	local RCVFILE=`mktemp`
	nc $_NCV -4 -n -l -k $PORT > $RCVFILE &
	local RCVPID=$!
	tail -f $RCVFILE | while read TOK
	do
		if [ -z $2 ] || [ "$TOK" = "$2" ]; then
			kill $RCVPID
			break
		fi
		#sleep 1
	done
	rm $RCVFILE
	# If we were not waiting for a specific token,
	# tell the caller what we actually got.
	[ -z $2 ] && echo $TOK
}

# We reached a state. We let the controller know that, by sending the
# token. Right after that, we wait here until the server norify us
# (by sending us the same token) that also all the others have reached
# the same state, and we therefore can proceed all together.
#
# $1: the token that we send, and that we also wait the controller
#     to send us back.
function mmtests_wait_token() {
	[ -z $MMTESTS_HOST_IP ] && return
	mmtests_send_token $MMTESTS_HOST_IP $MMTESTS_HOST_PORT $1
	mmtests_recv_token $MMTESTS_GUEST_PORT $1
}

# Send a token to one or more IPs:PORT. Even if there is more than one IP,
# the same PORT will be used for sending all the tokens.
#
# Also, the token are sent in parallel to all the IPs that are specified.
# The function that we call for sending them, needs to be exported (because
# so GNU parallel requires).
export -f mmtests_send_token
function mmtests_signal_token() {
	[ -z $MMTESTS_HOST_IP ] && return
	TOKEN=$1 ; shift
	parallel -j 4 mmtests_send_token {1} $MMTESTS_GUEST_PORT $TOKEN ::: $@ :::
}

MMTESTS_NUMACTL=
function set_mmtests_numactl() {
	local THIS_INSTANCE=$1
	local MAX_INSTANCE=$2

	if [ "$MMTESTS_NUMA_POLICY" = "" -o "$MMTESTS_NUMA_POLICY" = "none" ]; then
		MMTESTS_NUMACTL=
		return
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "interleave" ]; then
		MMTESTS_NUMACTL="numactl --interleave=all"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "local" ]; then
		MMTESTS_NUMACTL="numactl -l"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "fullbind_single_instance_node" ]; then
		local NODE_INDEX=$(($THIS_INSTANCE%$NUMNODES+1))
		local NODE_DETAILS=`numactl --hardware | grep cpus: | head -$NODE_INDEX | tail -1`
		local NODE_ID=`echo $NODE_DETAILS | awk '{print $2}'`

		MMTESTS_NUMACTL="numactl --cpunodebind=$NODE_ID --membind=$NODE_ID"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "fullbind_single_instance_cpu" ]; then
		local NODE_INDEX=$(($THIS_INSTANCE%$NUMNODES+1))
		local NODE_DETAILS=`numactl --hardware | grep cpus: | head -$NODE_INDEX | tail -1`
		local NODE_ID=`echo $NODE_DETAILS | awk '{print $2}'`
		local CPU_ID=`echo $NODE_DETAILS | awk '{print $4}'`

		MMTESTS_NUMACTL="numactl --physcpubind=$CPU_ID --membind=$NODE_ID"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "membind_single_instance_node" ]; then
		local NODE_INDEX=$(($THIS_INSTANCE%$NUMNODES+1))
		local NODE_DETAILS=`numactl --hardware | grep cpus: | head -$NODE_INDEX | tail -1`
		local NODE_ID=`echo $NODE_DETAILS | awk '{print $2}'`

		MMTESTS_NUMACTL="numactl --membind=$NODE_ID"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "cpubind_single_instance_node" ]; then
		local NODE_INDEX=$(($THIS_INSTANCE%$NUMNODES+1))
		local NODE_DETAILS=`numactl --hardware | grep cpus: | head -$NODE_INDEX | tail -1`
		local NODE_ID=`echo $NODE_DETAILS | awk '{print $2}'`

		MMTESTS_NUMACTL="numactl --cpunodebind=$NODE_ID"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "cpubind_specific_node" ]; then
		MMTESTS_NUMACTL="numactl --cpunodebind=$MMTESTS_NODE_ID"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "cpubind_largest_memory" ]; then
		MMTESTS_NODE_ID=`numactl --hardware | grep "^node" | grep size | sort -n -k 4 | tail -1 | awk '{print $2}'`
		echo Setting target node for CPUs to $MMTESTS_NODE_ID
		MMTESTS_NUMACTL="numactl --cpunodebind=$MMTESTS_NODE_ID"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "cpubind_largest_nonnode0_memory" ]; then
		MMTESTS_NODE_ID=`numactl --hardware | grep "^node" | grep -v "node 0" | grep size | sort -n -k 4 | tail -1 | awk '{print $2}'`
		if [ "$MMTESTS_NODE_ID" = "" ]; then
			MMTESTS_NODE_ID=0
		fi
		echo Setting target node for CPUs to $MMTESTS_NODE_ID
		MMTESTS_NUMACTL="numactl --cpunodebind=$MMTESTS_NODE_ID"
	fi

	if [ "$MMTESTS_NUMA_POLICY" = "cpubind_node_nrcpus" ]; then
		if [ "$MMTESTS_NUMA_NODE_NRCPUS" = "" ]; then
			die cpubind_node_nrcpus requires MMTESTS_NUMA_NODE_NRCPUS
		fi
		local NUMA_NODE=`echo $MMTESTS_NUMA_NODE_NRCPUS | awk -F , '{print $1}'`
		local BIND_CPUS=`echo $MMTESTS_NUMA_NODE_NRCPUS | awk -F , '{print $2}'`
		local AVAILABLE_CPUS_STR=`numactl --hardware | grep "^node $NUMA_NODE cpus:" | awk -F ': ' '{print $2}'`

		if [ "$BIND_CPUS" = "" ]; then
			die Unable to parse MMTESTS_NUMA_NODE_NRCPUS
		fi

		declare -a AVAILABLE_CPUS
		AVAILABLE_CPUS=($AVAILABLE_CPUS_STR)

		CPU_BIND_STRING=
		for i in `seq 0 $((BIND_CPUS-1))`; do
			CPUID=${AVAILABLE_CPUS[$i]}
			if [ "$CPUID" = "" ]; then
				die cpubind_node_nrcpus requested more cpus than are available on node $NUMA_NODE
			fi
			if [ "$CPU_BIND_STRING" != "" ]; then
				CPU_BIND_STRING=$CPU_BIND_STRING,
			fi
			CPU_BIND_STRING=$CPU_BIND_STRING$CPUID
		done

		MMTESTS_NUMACTL="numactl --membind $NUMA_NODE -C $CPU_BIND_STRING"
	fi

	if [ "$MMTESTS_NUMACTL" != "" ]; then
		echo "MMTESTS_NUMACTL: $MMTESTS_NUMACTL"
		echo Instance $THIS_INSTANCE / $MAX_INSTANCE
	fi
}

function mmtests_server_ctl() {
	if [ "$REMOTE_SERVER_HOST" = "" ]; then
		return
	fi

	echo === BEGIN execute remote server command: $REMOTE_SERVER_SCRIPT $@ ===

	# These max and default socket sizes were selected to allow netperf UDP_STREAM
	# the option of transmitting at the maximum rate with minimal packet loss on a
	# 10GbE network. Other networks and devices may have different requirements.
	# The maximum values are beyond excessive
	MAX_SIZE=33554432
	echo Setting local rmem_max and wmem_max to $MAX_SIZE
	sysctl net.core.rmem_max=$MAX_SIZE
	sysctl net.core.wmem_max=$MAX_SIZE
	echo Setting remote rmem_max and wmem_max to $MAX_SIZE
	ssh -o StrictHostKeyChecking=no $REMOTE_SERVER_USER@$REMOTE_SERVER_HOST sysctl net.core.rmem_max=$MAX_SIZE
	ssh -o StrictHostKeyChecking=no $REMOTE_SERVER_USER@$REMOTE_SERVER_HOST sysctl net.core.wmem_max=$MAX_SIZE

	# Start remote server
	ssh -o StrictHostKeyChecking=no $REMOTE_SERVER_USER@$REMOTE_SERVER_HOST $REMOTE_SERVER_WRAPPER $REMOTE_SERVER_SCRIPT --serverside-command $@
	if [ $? -ne $SHELLPACK_SUCCESS ]; then
		die Server side command failed
	fi
	echo === END execute remote server command: $REMOTE_SERVER_SCRIPT $@ ===
}

function mmtests_server_init() {
	SERVER_CTL_RCMD="ssh $REMOTE_SERVER_USER@$REMOTE_SERVER_HOST"

	if [ "$REMOTE_SERVER_HOST" = "" ]; then
		return
	fi

	echo === BEGIN execute remote server command: $REMOTE_SERVER_SCRIPT --install-only ===
	ssh -o StrictHostKeyChecking=no $REMOTE_SERVER_USER@$REMOTE_SERVER_HOST $REMOTE_SERVER_WRAPPER $REMOTE_SERVER_SCRIPT --install-only

	if [ $? -ne $SHELLPACK_SUCCESS ]; then
		die Server side installation failed
	fi
	echo === END execute remote server command: $REMOTE_SERVER_SCRIPT --install-only ===
}

function create_random_file() {
	SIZE=$1
	OUTPUT=$2
	if [ "$SHELLPACK_TEMP" = "" ]; then
		die SHELLPACK_TEMP is not set
	fi

	echo Creating file $OUTPUT of size $((SIZE/1048576)) MB filled with garbage
	dd if=/dev/urandom of=$SHELLPACK_TEMP/random_base_file ibs=1048575 count=20 2> /dev/null

	if [ -e $OUTPUT ]; then
		echo Removing existing $OUTPUT file
		rm -f $OUTPUT || die Failed to remove existing output file $OUTPUTT
	fi

	BASE_SIZE=$((1048575*20))
	while [ $SIZE -gt 0 ]; do
		if [ $SIZE -gt $BASE_SIZE ]; then
			dd if=$SHELLPACK_TEMP/random_base_file of=$OUTPUT oflag=append conv=notrunc 2> /dev/null
			SIZE=$((SIZE-$BASE_SIZE))
		else
			dd if=$SHELLPACK_TEMP/random_base_file of=$OUTPUT oflag=append conv=notrunc ibs=$SIZE obs=$SIZE 2>/dev/null
			SIZE=0
		fi
	done
	rm $SHELLPACK_TEMP/random_base_file
	ls -lh $OUTPUT
	sync
}

function setup_io_scheduler() {
	for i in ${!TESTDISK_PARTITIONS[*]}; do
		DEVICE=$(basename $(realpath ${TESTDISK_PARTITIONS[$i]}))
		while [ ! -e /sys/block/$DEVICE/queue/scheduler ]; do
			DEVICE=`echo $DEVICE | sed -e 's/.$//'`
			if [ "$DEVICE" = "" ]; then
				break
			fi
		done

		if [ "$TESTDISK_IO_SCHEDULER" != "" ]; then
			if [ "$DEVICE" = "" ]; then
				die "Unable to get an IO scheduler for ${TESTDISK_PARTITIONS[$i]}"
			fi
			echo Set IO scheduler $TESTDISK_IO_SCHEDULER on $DEVICE
			echo $TESTDISK_IO_SCHEDULER > /sys/block/$DEVICE/queue/scheduler || die "Failed to set IO scheduler $TESTDISK_IO_SCHEDULER on /sys/block/$DEVICE/queue/scheduler"

			if [ "$TESTDISK_IO_SCHEDULER_LOW_LATENCY" != "" ]; then
				echo Setting IO scheduler low_latency to $TESTDISK_IO_SCHEDULER_LOW_LATENCY
				echo $TESTDISK_IO_SCHEDULER_LOW_LATENCY > /sys/block/$DEVICE/queue/iosched/low_latency || die "Failed to set IO scheduler low_latency to $TESTDISK_IO_SCHEDULER_LOW_LATENCY"
			fi
			grep -H . /sys/block/$DEVICE/queue/scheduler
			lsscsi | grep $DEVICE
		fi
		grep -r -H . /sys/block/$DEVICE/queue/* 2> /dev/null >> $SHELLPACK_LOG/storageioqueue.txt
		grep -r -H . /sys/block/*/queue/* 2> /dev/null >> $SHELLPACK_LOG/storageioqueue-all.txt
	done
}

function setup_cgroups()
{
	declare -axg CGROUP_TASKS
	if [ "$CGROUP_MEMORY_SIZE" != "" ]; then
		mkdir -p /sys/fs/cgroup/memory/0 || die "Failed to create memory cgroup"
		echo $CGROUP_MEMORY_SIZE > /sys/fs/cgroup/memory/0/memory.limit_in_bytes || die "Failed to set memory limit"
		echo Memory limit configured: `cat /sys/fs/cgroup/memory/0/memory.limit_in_bytes`
		CGROUP_TASKS[0]=/sys/fs/cgroup/memory/0/tasks
	fi
	if [ "$CGROUP_CPU_TAG" != "" ]; then
		mkdir -p /sys/fs/cgroup/cpu/0 || die "Failed to create cpu cgroup"
		echo $CGROUP_CPU_TAG > /sys/fs/cgroup/cpu/0/cpu.tag || die "Failed to create CPU sched tag"
		echo CPU Tags set: `cat /sys/fs/cgroup/cpu/0/cpu.tag`
		CGROUP_TASKS[1]=/sys/fs/cgroup/cpu/0/tasks
	fi
	if [ "$CGROUP_BLKIO_BFQ_WEIGHT" != "" ]; then
		mkdir -p /sys/fs/cgroup/blkio/0 || die "Failed to create blkio cgroup"
		echo $CGROUP_BLKIO_BFQ_WEIGHT > /sys/fs/cgroup/blkio/0/blkio.bfq.weight || die "Failed to set blkio BFQ weight"
		echo BLKIO BFQ weight set: `cat /sys/fs/cgroup/blkio/0/blkio.bfq.weight`
		CGROUP_TASKS[2]=/sys/fs/cgroup/blkio/0/tasks
	fi
}

function create_testdisk()
{
	rm -f $SHELLPACK_LOG/storageioqueue.txt

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
		echo -n > $SHELLPACK_LOG/disk-raid-hdparm
		echo -n > $SHELLPACK_LOG/disk-raid-smartctl
		for DISK in $TESTDISK_RAID_DEVICES; do
			if [ "`uname -r`" != "4.4.52-0.g56e0224-default" ]; then
				hdparm -I $DISK 2>&1 >> $SHELLPACK_LOG/disk-raid-hdparm
				smartctl -a $DISK 2>&1 >> $SHELLPACK_LOG/dks-raid-smartctl
			fi
		done

		# Check if a suitable device is already assembled
		echo Scanning and assembling existing devices: $TESTDISK_RAID_DEVICES
		mdadm --assemble --scan
		FULL_ASSEMBLY_REQUIRED=no
		LAST_MD_DEVICE=
		SYMLINKED=no
		for DEVICE in $TESTDISK_RAID_DEVICES; do
			BASE_DEVICE=`basename $DEVICE`
			MD_DEVICE=`grep $BASE_DEVICE /proc/mdstat 2>/dev/null | sed -e 's/(auto-read-only)//' | awk '{print $1}'`
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

			PERSONALITY=`grep $BASE_DEVICE /proc/mdstat 2>/dev/null | awk '{print $4}'`
			if [ "$PERSONALITY" != "$TESTDISK_RAID_TYPE" ]; then
				echo o Device $DEVICE is part of a $PERSONALITY array instead of $TESTDISK_RAID_TYPE, assembly required
				FULL_ASSEMBLY_REQUIRED=yes
				continue
			fi
			if [ "/dev/$MD_DEVICE" != "$TESTDISK_RAID_MD_DEVICE" ]; then
				if [ ! -e $TESTDISK_RAID_MD_DEVICE ]; then
					echo o MD Device $MD_DEVICE does not match expected md0, linking
					ln -s /dev/$MD_DEVICE $TESTDISK_RAID_MD_DEVICE
					SYMLINKED=yes
				else
					echo o MD Device $MD_DEVICE does not match expected md0, doing full assembly
					FULL_ASSEMBLY_REQUIRED=yes
					continue
				fi
			fi
		done

		if [ "$FULL_ASSEMBLY_REQUIRED" = "yes" ]; then
			echo Full assembly required for mdstat state
			cat /proc/mdstat 2>/dev/null
			rm -f /etc/mdadm/mdadm.conf

			if [ "$SYMLINKED" != "no" ]; then
				echo Removing symbolic link for reassembly
				rm $TESTDISK_RAID_MD_DEVICE
			fi

			echo Removing old RAID device $MD_DEVICE
			vgremove -f mmtests-raid
			mdadm --remove $TESTDISK_RAID_MD_DEVICE
			mdadm --stop $TESTDISK_RAID_MD_DEVICE
			mdadm --remove $TESTDISK_RAID_MD_DEVICE

			echo Stopping other RAID devices
			for DEVICE in `grep ^md /proc/mdstat | awk '{print $1}'`; do
				echo o /dev/$DEVICE
				mdadm --stop /dev/$DEVICE
			done

			echo Creation start: `date`
			for DEVICE in $TESTDISK_RAID_DEVICES; do
				BASE_DEVICE=`basename $DEVICE`
				MD_DEVICE=`grep $BASE_DEVICE /proc/mdstat 2>/dev/null | awk '{print $1}'`

				if [ "$MD_DEVICE" != "" ]; then
					echo Cleaning up old device $MD_DEVICE for $BASE_DEVICE
					vgremove -f mmtests-raid
					mdadm --remove $TESTDISK_RAID_MD_DEVICE
					mdadm --stop $TESTDISK_RAID_MD_DEVICE
					mdadm --remove $TESTDISK_RAID_MD_DEVICE
				fi

				MD_DEVICE=`grep $BASE_DEVICE /proc/mdstat 2>/dev/null | awk '{print $1}'`
				if [ "$MD_DEVICE" != "" ]; then
					echo Shutting down all md devices related to devices
					for DEVICE in $TESTDISK_RAID_DEVICES; do
						BASE_DEVICE=`basename $DEVICE`
						echo -n "o $BASE_DEVICE: "
						for MD_DEVICE in `grep ^md /proc/mdstat 2>/dev/null | grep $BASE_DEVICE | awk '{print $1}'`; do
							mdadm --stop /dev/$MD_DEVICE
							echo -n "$MD_DEVICE "
						done
						echo
					done
				fi
			done

			for DISK in $TESTDISK_RAID_DEVICES; do
				echo
				echo Deleting partitions on disk $DISK
				parted -s $DISK mktable msdos

				echo Creating partitions on $DISK
				parted -s --align optimal $DISK mkpart primary $TESTDISK_RAID_OFFSET $TESTDISK_RAID_SIZE || die Failed to create aligned partition with parted

				echo Attempting discard on ${DISK}1
				blkdiscard ${DISK}1
				ATTEMPT=0
				OUTPUT=`mdadm --zero-superblock ${DISK}1 2>&1 | grep "not zeroing"`
				while [ "$OUTPUT" != "" ]; do
					echo Retrying superblock zeroing of ${DISK}1
					sleep 1
					mdadm --stop $TESTDISK_RAID_MD_DEVICE
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
				echo mdadm --create $TESTDISK_RAID_MD_DEVICE --name=0 -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
				EXPECT_SCRIPT=`mktemp`
				cat > $EXPECT_SCRIPT <<EOF
spawn mdadm --create $TESTDISK_RAID_MD_DEVICE --name=0 -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
expect {
	"Continue creating array?" { send yes\\r; exp_continue}
	"Really INITIALIZE"        { send y\\r; exp_continue}
	"Wipe it"		   { send y\\r; exp_continue}
}
EOF
				expect -f $EXPECT_SCRIPT || exit -1
				rm $EXPECT_SCRIPT
				;;
			raid5)
				echo mdadm --create $TESTDISK_RAID_MD_DEVICE --name=0 --bitmap=internal -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
				EXPECT_SCRIPT=`mktemp`
				cat > $EXPECT_SCRIPT <<EOF
spawn mdadm --create $TESTDISK_RAID_MD_DEVICE --name=0 --bitmap=internal -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
expect {
	"Continue creating array?" { send yes\\r; exp_continue}
	"Really INITIALIZE"        { send y\\r; exp_continue}
	"Wipe it"		   { send y\\r; exp_continue}
}
EOF
				expect -f $EXPECT_SCRIPT || exit -1
				rm $EXPECT_SCRIPT

				;;
			*)
				echo mdadm --create $TESTDISK_RAID_MD_DEVICE --name=0 -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
				EXPECT_SCRIPT=`mktemp`
				cat > $EXPECT_SCRIPT <<EOF
spawn mdadm --create $TESTDISK_RAID_MD_DEVICE --name=0 -l $TESTDISK_RAID_TYPE -n $NR_DEVICES $TESTDISK_RAID_PARTITIONS
expect {
	"Continue creating array?" { send yes\\r; exp_continue}
	"Really INITIALIZE"        { send y\\r; exp_continue}
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
		cat /proc/mdstat			| tee    $SHELLPACK_LOG/md-stat
		mdadm --detail $TESTDISK_RAID_MD_DEVICE | tee -a $SHELLPACK_LOG/md-stat

		mkdir -p /etc/mdadm
		mdadm --detail --scan > /etc/mdadm/mdadm.conf

		# Create LVM device of a fixed name. This is in case the blktrace
		# monitor is in use. For reasons I did not bother tracking down,
		# blktrace does not capture events from MD devices properly on
		# at least kernel 3.0
		echo Destroying logical volume
		vgremove -f mmtests-raid
		echo Creating logical volume
		yes y | pvcreate -ff $TESTDISK_RAID_MD_DEVICE || exit
		vgcreate mmtests-raid $TESTDISK_RAID_MD_DEVICE || exit
		SIZE=`vgdisplay mmtests-raid | grep Free | grep PE | awk '{print $5}'`
		if [ "$SIZE" = "" ]; then
			die Failed to determine LVM size
		fi
		echo lvcreate -l $SIZE mmtests-raid -n lvm0
		EXPECT_SCRIPT=`mktemp`
		cat > $EXPECT_SCRIPT <<EOF
spawn lvcreate -l $SIZE mmtests-raid -n lvm0
expect {
	"Really INITIALIZE"        { send y\\r; exp_continue}
	"Wipe it"		   { send y\\r; exp_continue}
}
EOF
		expect -f $EXPECT_SCRIPT || exit -1
		rm $EXPECT_SCRIPT


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
		if [ "$TESTDISK_RD_PREALLOC" == "yes" ]; then
			if [ "$TESTDISK_RD_PREALLOC_NODE" != "" ]; then
				tmp_prealloc_cmd="numactl -N $TESTDISK_RD_PREALLOC_NODE"
			else
				tmp_prealloc_cmd="numactl -i all"
			fi
			$tmp_prealloc_cmd dd if=/dev/zero of=/dev/ram0 bs=1M &>/dev/null
		fi

		if [ "$TESTDISK_FILESYSTEM" != "" ]; then
			export TESTDISK_PARTITION=/dev/ram0
		fi
	fi

	# Create storage cache device
	if [ "${STORAGE_CACHE_TYPE}" = "dm-cache" ]; then
		if [ "${STORAGE_CACHING_DEVICE}" = "" -o \
			"${STORAGE_BACKING_DEVICE}" = "" ]; then
			echo "ERROR: no caching and/or backing device specified"
			exit 1
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
}

function destroy_testdisk
{
	if [ "${STORAGE_CACHE_TYPE}" = "dm-cache" ]; then
		./bin/dmcache-setup.sh -c ${STORAGE_CACHING_DEVICE} \
			-b ${STORAGE_BACKING_DEVICE} -d
	elif [ "${STORAGE_CACHE_TYPE}" = "bcache" ]; then
		./bin/bcache-setup.sh -c ${STORAGE_CACHING_DEVICE} \
		    -b ${STORAGE_BACKING_DEVICE} -d
	fi
	if [ "$TESTDISK_RD_SIZE" != "" ]; then
		rmmod brd
	fi
	if [ "$TESTDISK_NBD_DEVICE" != "" ]; then
		nbd-client -d $TESTDISK_NBD_DEVICE
	fi
}

function create_filesystems
{
	if [ ${#TESTDISK_PARTITIONS[*]} -gt 0 ]; then
		if [ "${STORAGE_CACHE_TYPE}" = "" ]; then
			# Temporary hack for SLE 12 SP3 Alpha 2 testing
			if [ "`uname -r`" != "4.4.52-0.g56e0224-default" ]; then
				hdparm -I ${TESTDISK_PARTITIONS[*]} 2>&1 > $SHELLPACK_LOG/disk-hdparm
			fi
		fi
		if [ "$TESTDISK_FILESYSTEM" != "" -a "$TESTDISK_FILESYSTEM" != "tmpfs" ]; then
			if [ "${TESTDISK_FS_SIZE}" != "" ]; then
				case "${TESTDISK_FILESYSTEM}" in
				ext2|ext3|ext4)
					TESTDISK_MKFS_PARAM_SUFFIX="${TESTDISK_FS_SIZE}"
				;;
				xfs)
					TESTDISK_MKFS_PARAM="${TESTDISK_MKFS_PARAM} -d size=${TESTDISK_FS_SIZE}"
					;;
				btrfs)
					TESTDISK_MKFS_PARAM="${TESTDISK_MKFS_PARAM} -b ${TESTDISK_FS_SIZE}"
					;;
				esac
			fi
			for i in ${!TESTDISK_PARTITIONS[*]}; do
				echo Formatting test disk ${TESTDISK_PARTITIONS[$i]}: $TESTDISK_FILESYSTEM
				mkfs.$TESTDISK_FILESYSTEM $TESTDISK_MKFS_PARAM \
					${TESTDISK_PARTITIONS[$i]} \
					${TESTDISK_MKFS_PARAM_SUFFIX} || exit
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
		echo Attempting trim of $SHELLPACK_TEST_MOUNT
		time fstrim -v $SHELLPACK_TEST_MOUNT
		export TESTDISK_PRIMARY_SIZE_BYTES=`df $SHELLPACK_TEST_MOUNT | tail -1 | awk '{print $4}'`
		export TESTDISK_PRIMARY_SIZE_BYTES=$((TESTDISK_PRIMARY_SIZE_BYTES*1024))

		for i in ${!TESTDISK_PARTITIONS[*]}; do
			if [ $i -eq 0 ]; then
				SHELLPACK_TEST_MOUNTS[$i]=$SHELLPACK_TEST_MOUNT
				echo Creating tmp, sources, and data
				mkdir -p $SHELLPACK_SOURCES
				mkdir -p $SHELLPACK_TEMP
				mkdir -p $SHELLPACK_DATA
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

			echo Attempting trim of ${SHELLPACK_TEST_MOUNTS[$i]}
			time fstrim -v ${SHELLPACK_TEST_MOUNTS[$i]}
		done
	fi

	# Create NFS mount
	if [ "$TESTDISK_NFS_MOUNT" != "" ]; then
		/etc/init.d/nfs-common start
		/etc/init.d/rpcbind start
		mount -t nfs $TESTDISK_NFS_MOUNT $SHELLPACK_TEST_MOUNT || exit
	fi

	# Flush dm-cache before we start real testing so that mkfs data does
	# not pollute it
	# FIXME: Handle bcache as well
	if [ "${STORAGE_CACHE_TYPE}" = "dm-cache" ]; then
		./bin/dmcache-setup.sh -c ${STORAGE_CACHING_DEVICE} \
        	    -b ${STORAGE_BACKING_DEVICE} -f ||
		(echo "ERROR: dmcache-setup failed" \
		    "(dmcache-setup.sh -c ${STORAGE_CACHING_DEVICE}" \
		    "-b ${STORAGE_BACKING_DEVICE} -f)"; exit 1)
	fi
}

function umount_filesystems
{
	for DEV in ${TESTDISK_PARTITIONS[*]} $TESTDISK_NFS_MOUNT; do
		umount $DEV
	done
}

function have_run_results()
{
	if [ -n "$1" ]; then
		LIST=`find $1 -maxdepth 3 -type f -name tests-activity 2>/dev/null`
	else
		LIST=`find -maxdepth 3 -type f -name tests-activity 2>/dev/null`
	fi
	if [ "$LIST" != "" ]; then
		return 0
	fi
	return 1
}

function have_monitor_results()
{
	local monitor=$1
	local runname=$2
	local contains=$3

	if [ -z "$contains" ]; then
		ls $runname/iter-*/$monitor-* &>/dev/null
	else
		# Here we grep all runnames to check whether event occured
		# in any run
		zgrep -q "$contains" $runname/iter-*/$monitor-* &>/dev/null
	fi
}

# Return list of benchmark names in given run. Currently we extract them from
# the first iteration only as we expect all iterations to run identical set
# of tests.
function run_report_name()
{
	if [ -e $1/iter-0/tests-activity ]; then
		awk '/^[0-9]* run-mmtests: begin / { print $4 }
		    /^[0-9]* run-mmtests: Iteration 0 end/ { exit }' <$1/iter-0/tests-activity
	else
		awk '/^[0-9]* run-mmtests: begin / { print $4 }
		     /^[0-9]* run-mmtests: Iteration 0 end/ { exit }' <$1/tests-activity
	fi
}

function run_results()
{
	FILES=`find -name "tests-activity"`
	grep -H . $FILES | \
		cut -d ' ' -f 1 | sort -n -k 2 -t ':' | \
		cut -d ':' -f 1 | sed -e 's|/iter-.*/tests-activity||' -e 's|/tests-activity||' -e 's|^./||' | uniq
}

function setup_dirs() {
	for DIRNAME in $SHELLPACK_TEMP $SHELLPACK_SOURCES $SHELLPACK_LOG_BASE $SHELLPACK_DATA; do
		if [ ! -e "$DIRNAME" ]; then
			mkdir -p "$DIRNAME"
		fi
	done
}

function force_performance_setup()
{
	echo Setting performance cpu settings

	# asume all cpus are setup to the same scaling governor...
	for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
		[ -f $CPUFREQ ] || continue; echo -n performance > $CPUFREQ
	done
	NOTURBO="/sys/devices/system/cpu/intel_pstate/no_turbo"
	[ -f "$NOTURBO" ] && echo 1 > $NOTURBO
}

function restore_performance_setup()
{
	[ $# -eq 0 ] && return
	if [ $# -eq 2 ]; then
		GV=$1
		TB=$2
	elif [ "$1" = "1" ] || [ "$1" = "0" ]; then
		TB=$1
	else
		GV=$1
	fi

	echo Restoring performance cpu settings

	if [ ! -z $GV ]; then
		for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor;
		do
			[ -f $CPUFREQ ] || continue; echo -n $GV > $CPUFREQ
		done
	fi
	if [ ! -z $TB ]; then
		NOTURBO="/sys/devices/system/cpu/intel_pstate/no_turbo"
		[ -f "$NOTURBO" ] && echo $TB > $NOTURBO
	fi
}

function sysstate_log()
{
	[ -z $SHELLPACK_LOG ] && return
	echo "$@" >> $SHELLPACK_SYSSTATEFILE
}

function teststate_log()
{
	[ -z $SHELLPACK_LOG ] && return
	sysstate_log "$@"
	echo "$@" >> $SHELLPACK_LOGFILE
}

function activity_log()
{
	[ -z $SHELLPACK_LOG ] && return
	echo `date +%s` "$@" >> $SHELLPACK_ACTIVITY
}

function sysstate_log_basic_info()
{
	[ -z $SHELLPACK_LOG ] && return
	sysstate_log "version :: `mmtests-rev-id`"
	sysstate_log "arch :: `uname -m`"
	sysstate_log "`ip addr show`"
	sysstate_log "mount :: start"
	sysstate_log "`mount`"
	sysstate_log "/proc/mounts :: start"
	sysstate_log "`cat /proc/mounts`"
}

function sysstate_log_proc_files()
{
	[ -z $SHELLPACK_LOG ] && return
	PROC_FILES="/proc/vmstat /proc/zoneinfo /proc/meminfo /proc/schedstat /proc/diskstats"
	for PROC_FILE in $PROC_FILES; do
		sysstate_log "file $1 :: $PROC_FILE"
		sysstate_log "`cat $PROC_FILE`"
	done
}

function collect_hardware_info()
{
	[ -z $SHELLPACK_LOG ] && return
	if [ "`which numactl 2> /dev/null`" != "" ]; then
		numactl --hardware > $SHELLPACK_LOG/numactl.txt
		gzip $SHELLPACK_LOG/numactl.txt
	fi
	if [ "`which lscpu 2> /dev/null`" != "" ]; then
		lscpu > $SHELLPACK_LOG/lscpu.txt
		gzip $SHELLPACK_LOG/lscpu.txt
	fi
	if [ "`which cpupower 2> /dev/null`" != "" ]; then
		cpupower frequency-info > $SHELLPACK_LOG/cpupower.txt
		gzip $SHELLPACK_LOG/cpupower.txt
	fi
	if [ "`which lstopo 2> /dev/null`" != "" ]; then
		lstopo $SHELLPACK_LOG/lstopo.pdf 2>/dev/null
		lstopo --output-format txt > $SHELLPACK_LOG/lstopo.txt
		gzip $SHELLPACK_LOG/lstopo.pdf
		gzip $SHELLPACK_LOG/lstopo.txt
	fi
	if [ "`which lsscsi 2> /dev/null`" != "" ]; then
		lsscsi > $SHELLPACK_LOG/lsscsi.txt
		gzip $SHELLPACK_LOG/lsscsi.txt
	fi
	if [ "`which list-cpu-toplogy.sh 2> /dev/null`" != "" ]; then
		list-cpu-toplogy.sh > $SHELLPACK_LOG/cpu-topology-mmtests.txt
		gzip $SHELLPACK_LOG/cpu-topology-mmtests.txt
	fi
	if [ "`which set-cstate-latency.pl 2> /dev/null`" != "" ]; then
		set-cstate-latency.pl > $SHELLPACK_LOG/cstate-latencies-${RUNNAME}.txt
	fi
	if [ -e /sys/devices/system/cpu/vulnerabilities ]; then
		grep . /sys/devices/system/cpu/vulnerabilities/* > $SHELLPACK_LOG/cpu-vulnerabilities.txt
	fi
	if [ -e /sys/devices/system/cpu/cpu0/cpuidle ]; then
		grep . /sys/devices/system/cpu/cpu0/cpuidle/state*/latency > $SHELLPACK_LOG/cpuidle-latencies.txt
		tar -czf $SHELLPACK_LOG/cpuidle.tar.gz /sys/devices/system/cpu/cpu0/cpuidle
	fi
}

function collect_kernel_info()
{
	[ -z $SHELLPACK_LOG ] && return
	uname -a > $SHELLPACK_LOG/kernel.version
	cp /boot/config-`uname -r` $SHELLPACK_LOG/kconfig-`uname -r`.txt
	gzip -f $SHELLPACK_LOG/kconfig-`uname -r`.txt
}

function collect_sysconfig_info()
{
	[ -z $SHELLPACK_LOG ] && return
	if [ -d /sys/fs/cgroup ]; then
		if [ "`which tree 2> /dev/null`" != "" ]; then
			tree -alfDn /sys/fs/cgroup > $SHELLPACK_LOG/cgroup-tree.txt
			gzip $SHELLPACK_LOG/cgroup-tree.txt
		fi
	fi

	for FILE in `find /sys/fs/cgroup -name tasks 2> /dev/null | grep user-$UID.slice`; do
		grep -H "^$$\$" $FILE >> $SHELLPACK_LOG/cgroup-tasks-v1.txt
	done

	for FILE in `find /sys/fs/cgroup/user.slice/user-$UID.slice -name cgroup.procs 2> /dev/null`; do
		NR=`wc -l $FILE | awk '{print $1}'`
		if [ $NR -eq 0 ]; then
			continue
		fi
		WITHIN="inactive"
		grep -q "^$$\$" $FILE
		if [ $? -eq 0 ]; then
			WITHIN=" ACTIVE "
		fi

		CONTROLLERS=`echo $FILE | sed -e 's/cgroup.procs/cgroup.controllers/'`
		echo "o $WITHIN nr:`wc -l $FILE | awk '{print $1}'` controllers:`cat $CONTROLLERS` : $FILE" >> $SHELLPACK_LOG/cgroup-tasks-v2.txt
	done
}

function round_down_power_2()
{
	local input_val=$1
	local power=1

	while [ $((1<<$power)) -le $input_val ]; do
		power=$((power+1))
	done
	echo $((1<<(power-1)))
}

function round_down_nearest_square()
{
	local input_val=$1
	local square

	square=`echo "sqrt($input_val) / 1" | bc`
	echo $((square*square))
}
