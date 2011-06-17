#!/bin/bash
# Copyright Michal Hocko 2011
# Copyright Mel Gorman 2011

if [ ! -e /cgroups/memory.stat ]; then
	echo Mounting cgroups
	mount -t cgroup none /cgroups -o memory
	if [ ! -e /cgroups/memory.stat ]; then
		echo ERROR: Failed to mount cgroups
		exit -1
	fi
fi

# If the kernel doesn't support OOM control, finish without error
if [ ! -e /cgroups/memory.oom_control ]; then
	echo Irrelevant: OOM Control not supported
	exit 0
fi

echo WARNING: Disabling all swap, will not restore after test
swapoff -a

# Create the cgroup
if [ -e /cgroups/$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME ]; then
	echo WARNING: $MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME already existed
fi
if [ "`which cgcreate`" != "" ]; then
	cgcreate -g memory:$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME || exit -1
else
	mkdir /cgroups/$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME
fi

echo $MICRO_MEMCG_OOMNOTIIFY_MEMCG_SIZE > /cgroups/$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME/memory.limit_in_bytes || exit -1
echo 1 > /cgroups/$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME/memory.oom_control || exit -1

SELF=$0
BITNESS=-m64
case `uname -m` in
i?86)
	BITNESS=
esac

# Build the mapping program
echo Building alloc and walk program
TEMPFILE=`mktemp`
LINECOUNT=`wc -l $0 | awk '{print $1}'`
CSTART=`grep -n "BEGIN C FILE" $0 | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$CSTART)) $0 | grep -v "^###" > $TEMPFILE.c
gcc $BITNESS -O2 $TEMPFILE.c -o alloc-and-walk || exit -1
gcc $BITNESS -O2 $SHELLPACK_TOPLEVEL/micro/cgroup_event_listener.c -o cgroup_event_listener || exit -1
cp $TEMPFILE.c /tmp/debug.c

# Parallel Notifier
START_TIME=`date +%s`
END_TIME=$((START_TIME+MICRO_MEMCG_OOMNOTIIFY_DURATION))
while [ `date +%s` -lt $((END_TIME+30)) -a -e ./cgroup_event_listener ]; do
	./cgroup_event_listener /cgroups/$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME/memory.oom_control || continue
	while grep "under_oom 1" /cgroups/$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME/memory.oom_control >/dev/null; do
		KILLPID=`tail -n1 /cgroups/$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME/tasks`
		kill -KILL $KILLPID 2> /dev/null
		HUNG_TIME=`date +%s`
		HUNG_TIME=$((HUNG_TIME+MICRO_MEMCG_OOMNOTIIFY_HANGTIME))
		echo -n Killing PID $KILLPID
		if [ "`ps h --pid $KILLPID`" != "" -a `date +%s` -lt $HUNG_TIME ]; then
			echo -n .
			sleep 1
		fi
		echo
		if [ "`ps h --pid $KILLPID`" != "" -a `date +%s` -ge $HUNG_TIME ]; then
			echo $KILLPID >> hung.pids
			echo FATAL: Failed to kill $KILLPID
			exit -1
		fi
		echo $KILLPID >> killed.pids
	done
	echo Not under OOM
done &

echo Launching tasks
echo -n > memcg-oom-notifier-$$.pids
for TASK in `seq 1 $MICRO_MEMCG_OOMNOTIIFY_NR_TASKS`; do
	if [ `which cgexec 2> /dev/null` != "" ]; then
		cgexec -g memory:$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME ./alloc-and-walk &
		PID=$!
		echo $PID >> memcg-oom-notifier-$$.pids
	else
		./alloc-and-walk &
		PID=$!
		echo $PID > /cgroups/$MICRO_MEMCG_OOMNOTIIFY_MEMCG_NAME/tasks
		echo $PID >> memcg-oom-notifier-$$.pids
	fi
done

echo Programs launched, running $MICRO_MEMCG_OOMNOTIIFY_DURATION seconds
sleep $MICRO_MEMCG_OOMNOTIIFY_DURATION

# Wait for memory pressure programs to exit
echo Killing alloc-and-walk tasks
for PID in `cat memcg-oom-notifier-$$.pids`; do
	if [ "`ps h --pid $PID`" != "" -a `date +%s` -lt $HUNG_TIME ]; then
		kill -9 $PID
		wait $PID
	fi
done
rm memcg-oom-notifier-$$.pids

# Check if we hung at any point
if [ -e hung.pids ]; then
	echo ERROR: Some pids hung for too long
	cat hung.pids
	exit -1
fi
exit 0

==== BEGIN C FILE ====
#include <stdlib.h>
#include <sys/mman.h>

#define K(v) (1024*(v))
#define M(v) (1024*K(v))

void walk(void *addr, size_t size)
{
	while (1) {
		unsigned char *p = addr,
			      *end = p + size;
		for (; p < end; p += 4096)
			*p = 1;
	}
}

int main()
{
	void *addr;
	size_t size = M(10);

	if ((addr = mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0)) == MAP_FAILED)
		return 1;
	walk(addr, size);
	return 0;
}
