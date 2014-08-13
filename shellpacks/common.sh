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

function wait_on_pid_exit() {
	WAITPID=$1

	if [ "$WAITPID" != "" ]; then
		echo -n Waiting on pid $WAITPID to shutdown
		while [ "`ps h --pid $WAITPID`" != "" ]; do
			echo -n .
			sleep 1
		done
		echo
	fi
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


	if [ "$MMTESTS_NUMACTL" != "" ]; then
		echo MMTESTS_NUMACTL: $MMTESTS_NUMACTL
		echo Instance $THIS_INSTANCE / $MAX_INSTANCE
	fi
}
