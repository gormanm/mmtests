#!/bin/bash

install-depends numactl

# Extract the memhog program
EXITING=0
TEMPFILE=`mktemp`
LINECOUNT=`wc -l $0 | awk '{print $1}'`
CSTART=`grep -n "BEGIN C FILE" $0 | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$CSTART)) $0 | grep -v "^###" > $TEMPFILE.c

# Build it
HOGSIZE=$((1048576*1024))
if [ "$MONITOR_NUMA_MEMHOG_SIZE_MB" != "" ]; then
	HOGSIZE=$((MONITOR_NUMA_MEMHOG_SIZE_MB*1048576))
fi
gcc -DHOGSIZE=$HOGSIZE -O2 $TEMPFILE.c -o $TEMPFILE || exit -1

# Trap interrupts
shutdown_memhog() {
	for HOGPID in `cat $TEMPFILE.pids`; do
		kill -9 $HOGPID
		echo Killed memhog pid $HOGPID
	done
	rm $TEMPFILE.pids
	EXITING=1
	exit 0
}
trap shutdown_memhog SIGTERM
trap shutdown_memhog SIGINT

NODES=`grep ^Node /proc/zoneinfo | awk '{print $2}' | sed -e 's/,//' | sort | uniq`
for NODE in $NODES; do
	numactl -m $NODE $TEMPFILE &
	HOGPID=$!
	echo $HOGPID >> $TEMPFILE.pids
	echo Started memhog pid $HOGPID node $NODE size $HOGSIZE
done

# Wait until interrupted
while [ 1 ]; do
	sleep 5

	if [ $EXITING -eq 1 ]; then
		exit 0
	fi

	# Check if the reader program exited abnormally
	for HOGPID in `cat $TEMPFILE.pids`; do
		ps -p $HOGPID > /dev/null
		if [ $? -ne 0 ]; then
			echo Memhog program exited abnormally
			exit -1
		fi
	done
done
	
==== BEGIN C FILE ====
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>

int main(int argc, char **argv)
{
	/* Assume HOGSIZE defined */
	char *buf = malloc(HOGSIZE);
	if (buf == NULL) {
		printf("ENOMEM");
		exit(EXIT_FAILURE);
	}

	if (mlock(buf, HOGSIZE) == -1) {
		perror("mlock");
		exit(EXIT_FAILURE);
	}

	while (1) {
		read(fileno(stdin), buf, 1);
		sleep(24*3600);
	}
}
