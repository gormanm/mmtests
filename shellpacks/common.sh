if [ -e $SCRIPTDIR/bash_arrays ]; then
	. $SCRIPTDIR/bash_arrays
fi
export SHELLPACK_ERROR=-1
export SHELLPACK_SUCCESS=0
if [ "$SCRIPTDIR" = "" ]; then
	echo $P: SCRIPTDIR not set, should not happen
	exit $SHELLPACK_ERROR
fi

if [ "`which check-confidence.pl 2> /dev/null`" = "" ]; then
	export PATH=$SCRIPTDIR/stat:$PATH
fi

MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
NUMCPUS=$(grep -c '^processor' /proc/cpuinfo)
NUMNODES=`grep ^Node /proc/zoneinfo | awk '{print $2}' | sort | uniq | wc -l`

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

	sleep 1
	echo -n "Waiting on pidfile \"`basename $PIDFILE`\" "
	while [ ! -e $PIDFILE ]; do
		echo -n O
		sleep 1
	done

	PIDWAIT=`cat $PIDFILE`
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

function file_fetch() {
	WEB=$1
	MIRROR=$2
	OUTPUT=$3

	if [ "$MMTESTS_IGNORE_MIRROR" != "yes" ]; then
		echo "$P: Fetching from mirror $MIRROR"
		wget -q -O $OUTPUT $MIRROR
	fi
	if [ "$MMTESTS_IGNORE_MIRROR" = "yes" -o $? -ne 0 ]; then
		if [ "$WEB" = "NOT_AVAILABLE" ]; then
			die Benchmark is not publicly available. You must make it available from a local mirror
		fi

		echo "$P: Fetching from internet $WEB"
		wget -q -O $OUTPUT $WEB
		if [ $? -ne 0 ]; then
			die "$P: Could not download $WEB"
		fi
	fi
}

function sources_fetch() {
	WEB=$1
	MIRROR=$2
	OUTPUT=$3

	if [ "$MMTESTS_IGNORE_MIRROR" != "yes" ]; then
		echo "$P: Fetching from mirror $MIRROR"
		wget -q -O $OUTPUT $MIRROR
	fi
	if [ "$MMTESTS_IGNORE_MIRROR" = "yes" -o $? -ne 0 ]; then
		if [ "$WEB" = "NOT_AVAILABLE" ]; then
			die Benchmark is not publicly available. You must make it available from a local mirror
		fi
			
		echo "$P: Fetching from internet $WEB"
		wget -q -O $OUTPUT $WEB
		if [ $? -ne 0 ]; then
			die "$P: Could not download $WEB"
		fi
	fi
}

function git_fetch() {
	GIT=$1
	TREE=$2
	MIRROR=$3
	OUTPUT=$4

	install-depends git-core

	if [ "$MMTESTS_IGNORE_MIRROR" != "yes" ]; then
		echo "$P: Fetching from mirror $MIRROR"
		wget -q -O $OUTPUT $MIRROR
	fi

	if [ "$MMTESTS_IGNORE_MIRROR" = "yes" -o $? -ne 0 ]; then
		if [ "$GIT" = "NOT_AVAILABLE" ]; then
			die Benchmark is not publicly available. You must make it available from a local mirror
		fi

		cd $SHELLPACK_SOURCES
		echo "$P: Cloning from internet $GIT"
		git clone $GIT $TREE
		if [ $? -ne 0 ]; then
			die "$P: Could not clone $GIT"
		fi
		cd $TREE || die "$P: Could not cd $TREE"
		echo Creating $OUTPUT
		git archive --format=tar --prefix=$TREE/ master | gzip -c > $OUTPUT
		cd -
	fi
}

function hg_fetch() {
	HG=$1
	TREE=$2
	MIRROR=$3
	OUTPUT=$4

	install-depends mercurial

	echo "$P: Fetching from mirror $MIRROR"
	wget -q -O $OUTPUT $MIRROR
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
