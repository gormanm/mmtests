#!/bin/bash
# This monitor writes a file in a continual loop recording the latency
# of a write. Certain applications, including terminals, can stall if
# they are not allowed to complete a small write
# 
# (c) Mel Gorman 2013

# Extract the writer program
TEMPFILE=`mktemp`
LINECOUNT=`wc -l $0 | awk '{print $1}'`
CSTART=`grep -n "BEGIN C FILE" $0 | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$CSTART)) $0 | grep -v "^###" > $TEMPFILE.c

install-depends gcc gcc-32bit autoconf automake bunutils-devel make patch

# Build it
WRITESIZE=
WRITEPAUSE=
BUILDRAND=
COUNT=100
IBS=1048576
if [ "$MONITOR_WRITE_LATENCY_RANDOM" = "yes" ]; then
	BUILDRAND=-DRANDWRITE
fi
if [ "$MONITOR_WRITE_LATENCY_WRITESIZE_MB" != "" ]; then
        IBS=$((MONITOR_WRITE_LATENCY_WRITESIZE_MB*1048576))
        WRITESIZE="-DBUFFER_SIZE=$IBS"

	# Bit arbitrary
	if [ $MONITOR_WRITE_LATENCY_WRITESIZE_MB -gt 16 ]; then
		COUNT=10
	fi
fi
if [ "$MONITOR_WRITE_LATENCY_WRITEPAUSE_MS" != "" ]; then
	WRITEPAUSE="-DBETWEENWRITE_PAUSE_MS=$MONITOR_WRITE_LATENCY_WRITEPAUSE_MS"
fi
if [ "$SHELLPACK_TEMP" != "" ]; then
	mkdir -p $SHELLPACK_TEMP || exit -1
	cd $SHELLPACK_TEMP || exit -1
fi

if [ "$MONITOR_WRITE_LATENCY_MULTIFILE" != "yes" ]; then
	# Build a file on local storage for the program to access
	dd if=/dev/zero of=monitor_writefile ibs=$IBS count=$COUNT > /dev/null 2> /dev/null
	MULTIFILE=
else
	# Build one file per expected buffer
	for i in `seq 0 $COUNT`; do
		dd if=/dev/zero of=monitor_writefile-$i ibs=$IBS count=1 > /dev/null 2> /dev/null
	done
	MULTIFILE="-DMULTIFILESLOTS=$COUNT"
fi

gcc -Wall $BUILDRAND $WRITESIZE $WRITEPAUSE $MULTIFILE ${MMTESTS_BUILD_CFLAGS:--O2} $TEMPFILE.c -o $TEMPFILE || exit -1

# Start the writer
$TEMPFILE monitor_writefile &
WRITER_PID=$!

# Handle being shutdown
EXITING=0
shutdown_write() {
	kill -9 $WRITER_PID
	rm $TEMPFILE
	rm -f monitor_writefile*
	if [ "$SHELLPACK_TEMP" != "" ]; then
		cd /
		rm -rf $SHELLPACK_TEMP
	fi
	EXITING=1
	exit 0
}
	
trap shutdown_write SIGTERM
trap shutdown_write SIGINT

while [ 1 ]; do
	sleep 5

	# Check if we should shutdown
	if [ $EXITING -eq 1 ]; then
		exit 0
	fi

	# Check if the writer program exited abnormally
	ps -p $WRITER_PID > /dev/null
	if [ $? -ne 0 ]; then
		echo Writer program exited abnormally
		exit -1
	fi
done


==== BEGIN C FILE ====
#define _GNU_SOURCE
#include <limits.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>

#ifndef BUFFER_SIZE
#define BUFFER_SIZE (1048576UL)		/* Buffer to write data into */
#endif
#ifndef BETWEENWRITE_PAUSE_MS
#define BETWEENWRITE_PAUSE_MS 1500
#endif

int main(int argc, char **argv)
{
	int fd;
	struct stat stat_buf;
	off_t filesize;
	off_t slots;
	char *buf;

	if (argc < 2) {
		fprintf(stderr, "Usage: watch-write-latency <file>\n");
		exit(EXIT_FAILURE);
	}

	/* Allocate the buffer to write from */
	buf = malloc(BUFFER_SIZE);
	if (buf == NULL) {
		fprintf(stderr, "Buffer allocation failed");
		exit(EXIT_FAILURE);
	}
	memset(buf, 1, BUFFER_SIZE);

#ifndef MULTIFILESLOTS
	/* Open file for writing */
	fd = open(argv[1], O_WRONLY);
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
#else
	filesize = 0;
	slots = MULTIFILESLOTS;
#endif

	/* Write until interrupted */
	while (1) {
		ssize_t position;
		ssize_t bytes_write;
		ssize_t slots_write = 0;
		struct timeval start, end, latency;

#ifndef MULTIFILESLOTS
		/* Seek to the start of the file */
		position = 0;
		slots_write = 0;
		if (lseek(fd, position, SEEK_SET) != position) {
			perror("lseek");
			exit(EXIT_FAILURE);
		}
#endif
		
		/* Write whole file measuring the latency of each access */
		while (slots_write++ < slots) {
			gettimeofday(&start, NULL);
#ifdef MULTIFILESLOTS
			do {
				char filename[PATH_MAX];
				snprintf(filename, PATH_MAX-2, "%s-%lu", argv[1], slots_write);

				/* Open file for writing */
				fd = open(filename, O_WRONLY);
				if (fd == -1) {
					perror("open");
					exit(EXIT_FAILURE);
				}
			} while (0);

			if (filesize == 0) {
				/* Get the length stat */
				if (fstat(fd, &stat_buf) == -1) {
					perror("fstat");
					exit(EXIT_FAILURE);
				}
				filesize = stat_buf.st_size & ~(BUFFER_SIZE-1);
			}
#endif

#if defined(RANDWRITE) && !defined(MULTIFILESLOTS)
			position = BUFFER_SIZE * (rand() % slots);
			if (lseek(fd, position, SEEK_SET) != position) {
				perror("lseek");
				exit(EXIT_FAILURE);
			}
#endif
#ifdef MULTIFILESLOTS
			position = 0;
#endif

			bytes_write = 0;
			while (bytes_write != BUFFER_SIZE) {
				ssize_t this_write = write(fd, buf + bytes_write, BUFFER_SIZE - bytes_write);
				if (this_write == -1) {
					perror("write");
					exit(EXIT_FAILURE);
				}
				if (this_write == 0)
					break;

				bytes_write += this_write;
			}

			if (sync_file_range(fd, position, BUFFER_SIZE, SYNC_FILE_RANGE_WAIT_BEFORE | SYNC_FILE_RANGE_WRITE | SYNC_FILE_RANGE_WAIT_AFTER) == -1) {
				perror("sync_file_range");
				exit(EXIT_FAILURE);
			}

			gettimeofday(&end, NULL);
			position += bytes_write;

#ifdef MULTIFILESLOTS
			close(fd);
#endif

			/* Print write latency in ms */
			printf("%lu.%lu ", end.tv_sec, end.tv_usec/1000);
			timersub(&end, &start, &latency);
			printf("%lu\n", (latency.tv_sec * 1000) + (latency.tv_usec / 1000));
			usleep(BETWEENWRITE_PAUSE_MS * 1000);
		}
	}
}
