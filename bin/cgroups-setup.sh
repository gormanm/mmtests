#!/bin/bash
set ${MMTESTS_SH_DEBUG:-+x}

DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME/.." && pwd`

. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh

function die() {
	echo "FATAL: $@"
	exit -1
}

# bash arrays are read in, we can return a extended list of arrays
declare -ax CGROUP_TASKS
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
declare -p | grep "\-ax" > $SCRIPTDIR/bash_arrays
