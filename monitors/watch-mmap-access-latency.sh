#!/bin/bash
# This monitor reads a file in a continual loop recording the latency
# of a read. Users complain that interactive performance can floor
# in certain circumstances like when writing to USB. In extreme cases,
# music jitter is reported. This program vagely simulates reading a
# music file but jitter in it could also imply problems with accessing
# config files
# 
# (c) Mel Gorman 2012

# Extract the reader program
TEMPFILE=`mktemp`
LINECOUNT=`wc -l $0 | awk '{print $1}'`
CSTART=`grep -n "BEGIN C FILE" $0 | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$CSTART)) $0 | grep -v "^###" > $TEMPFILE.c

install-depends gcc gcc-32bit autoconf automake bunutils-devel make patch

# Build it
READSIZE=
READPAUSE=
BUILDRAND=
IBS=64
if [ "$MONITOR_MMAP_ACCESS_LATENCY_RANDOM" = "yes" ]; then
	BUILDRAND=-DRANDREAD
fi
if [ "$MONITOR_MMAP_ACCESS_LATENCY_MAPSIZE_MB" = "" ]; then
	echo Must specify MONITOR_MMAP_ACCESS_LATENCY_MAPSIZE_MB
	exit $SHELLPACK_ERROR
fi
if [ "$MONITOR_MMAP_ACCESS_LATENCY_READPAUSE_MS" != "" ]; then
	READPAUSE="-DBETWEENREAD_PAUSE_MS=$MONITOR_MMAP_ACCESS_LATENCY_READPAUSE_MS"
fi

COUNT=$((MONITOR_MMAP_ACCESS_LATENCY_MAPSIZE_MB*1048576/IBS))
READSIZE="-DBUFFER_SIZE=$IBS"

if [ "$SHELLPACK_TEMP" != "" ]; then
	mkdir -p $SHELLPACK_TEMP || exit -1
        cd $SHELLPACK_TEMP || exit -1
fi
gcc -Wall $BUILDRAND $READSIZE $READPAUSE -O2 $TEMPFILE.c -o $TEMPFILE || exit -1

# Build a file on local storage for the program to access
dd if=/dev/zero of=monitor_readfile ibs=$IBS count=$COUNT > /dev/null 2> /dev/null

# Start the reader
$TEMPFILE monitor_readfile &
READER_PID=$!

# Handle being shutdown
EXITING=0
shutdown_read() {
	kill -9 $READER_PID
	rm $TEMPFILE
	rm monitor_readfile*
	if [ "$SHELLPACK_TEMP" != "" ]; then
		cd /
		rm -rf $SHELLPACK_TEMP
	fi
	EXITING=1
	exit 0
}
	
trap shutdown_read SIGTERM
trap shutdown_read SIGINT

while [ 1 ]; do
	sleep 5

	# Check if we should shutdown
	if [ $EXITING -eq 1 ]; then
		exit 0
	fi

	# Check if the reader program exited abnormally
	ps -p $READER_PID > /dev/null
	if [ $? -ne 0 ]; then
		echo Reader program exited abnormally
		exit -1
	fi
done

==== BEGIN C FILE ====
#include <limits.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/mman.h>

#ifndef BUFFER_SIZE
#define BUFFER_SIZE 64
#endif
#ifndef BETWEENREAD_PAUSE_MS
#define BETWEENREAD_PAUSE_MS 1500
#endif

int main(int argc, char **argv)
{
	int fd;
	struct stat stat_buf;
	off_t filesize;
	off_t slots;
	char *buf;
	int sum = 0;

	if (argc < 2) {
		fprintf(stderr, "Usage: watch-read-latency <file>\n");
		exit(EXIT_FAILURE);
	}

	/* Open file for reading */
	fd = open(argv[1], O_RDONLY);
	if (fd == -1) {
		perror("open");
		exit(EXIT_FAILURE);
	}

	/* Get the length stat */
	if (fstat(fd, &stat_buf) == -1) {
		perror("fstat");
		exit(EXIT_FAILURE);
	}
	filesize = stat_buf.st_size & ~(BUFFER_SIZE-1);
	slots = filesize / BUFFER_SIZE;

	/* Allocate the buffer to read into */
	buf = mmap(NULL, filesize, PROT_READ|PROT_EXEC, MAP_SHARED, fd, 0);
	if (buf == NULL) {
		fprintf(stderr, "mmap failed");
		exit(EXIT_FAILURE);
	}

	/* Read until interrupted */
	while (1) {
		ssize_t slots_read = 0;
		struct timeval start, end, latency;
		unsigned long long latency_us;
		int index;

		/* Read whole file measuring the latency of each access */
		while (slots_read++ < slots) {
			gettimeofday(&start, NULL);

#if defined(RANDREAD)
			index = BUFFER_SIZE * (rand() % slots);
#else
			index = BUFFER_SIZE * (slots_read % slots);
#endif
			/* sum is used below to make it impossible to optimise the access */
			sum += buf[index];
			gettimeofday(&end, NULL);

			/* Print read latency in ms */
			timersub(&end, &start, &latency);
			latency_us = (latency.tv_sec * 1000000) + (latency.tv_usec);
			if (latency_us >= 1000 && sum >= 0)
				printf("%lu.%lu %llu\n", end.tv_sec, end.tv_usec/1000, latency_us);
			if (BETWEENREAD_PAUSE_MS > 0)
				usleep(BETWEENREAD_PAUSE_MS * 1000);
		}

	}
	munmap(buf, filesize);
}
