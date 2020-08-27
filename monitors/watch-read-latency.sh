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
IBS=1048576
COUNT=100
if [ "$MONITOR_READ_LATENCY_RANDOM" = "yes" ]; then
	BUILDRAND=-DRANDREAD
fi
if [ "$MONITOR_READ_LATENCY_READSIZE_MB" != "" ]; then
	IBS=$((MONITOR_READ_LATENCY_READSIZE_MB*1048576))
	READSIZE="-DBUFFER_SIZE=$IBS"

	# Bit arbitrary
	if [ $MONITOR_READ_LATENCY_READSIZE_MB -gt 16 ]; then
		COUNT=10
	fi
fi
if [ "$MONITOR_READ_LATENCY_READPAUSE_MS" != "" ]; then
	READPAUSE="-DBETWEENREAD_PAUSE_MS=$MONITOR_READ_LATENCY_READPAUSE_MS"
fi
if [ "$SHELLPACK_TEMP" != "" ]; then
	mkdir -p $SHELLPACK_TEMP || exit -1
        cd $SHELLPACK_TEMP || exit -1
fi

if [ "$MONITOR_READ_LATENCY_MULTIFILE" != "yes" ]; then
	# Build a file on local storage for the program to access
	dd if=/dev/zero of=monitor_readfile ibs=$IBS count=$COUNT > /dev/null 2> /dev/null
	MULTIFILE=
else
	# Build one file per expected buffer
	for i in `seq 0 $COUNT`; do
		dd if=/dev/zero of=monitor_readfile-$i ibs=$IBS count=1 > /dev/null 2> /dev/null
	done
	MULTIFILE="-DMULTIFILESLOTS=$COUNT"
fi

sync
gcc $BUILDRAND $READSIZE $READPAUSE $MULTIFILE -O2 $TEMPFILE.c -o $TEMPFILE || exit -1

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

#ifndef BUFFER_SIZE
#define BUFFER_SIZE (1048576UL)		/* Buffer to read data into */
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

	if (argc < 2) {
		fprintf(stderr, "Usage: watch-read-latency <file>\n");
		exit(EXIT_FAILURE);
	}

	/* Allocate the buffer to read into */
	buf = malloc(BUFFER_SIZE);
	if (buf == NULL) {
		fprintf(stderr, "Buffer allocation failed");
		exit(EXIT_FAILURE);
	}

#ifndef MULTIFILESLOTS
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
#else
	filesize = 0;
	slots = MULTIFILESLOTS;
#endif

	/* Read until interrupted */
	while (1) {
		ssize_t position;
		ssize_t bytes_read;
		ssize_t slots_read = 0;
		struct timeval start, end, latency;

#ifndef MULTIFILESLOTS
		/* First, dump the file cache so it is an actual read */
		if (posix_fadvise(fd, 0, filesize, POSIX_FADV_DONTNEED) != 0) {
			perror("fadvise");
			exit(EXIT_FAILURE);
		}

		/* Seek to the start of the file */
		position = 0;
		slots_read = 0;
		if (lseek(fd, position, SEEK_SET) != position) {
			perror("lseek");
			exit(EXIT_FAILURE);
		}
#endif
		
		/* Read whole file measuring the latency of each access */
		while (slots_read++ < slots) {
			gettimeofday(&start, NULL);
#ifdef MULTIFILESLOTS
			do {
				char filename[PATH_MAX];
				snprintf(filename, PATH_MAX-1, "%s-%lu", argv[1], slots_read);

				/* Open file for reading */
				fd = open(filename, O_RDONLY);
				if (fd == -1) {
					perror("open");
					exit(EXIT_FAILURE);
				}
			} while(0);

			if (filesize == 0) {
				/* Get the length stat */
				if (fstat(fd, &stat_buf) == -1) {
					perror("fstat");
					exit(EXIT_FAILURE);
				}
				filesize = stat_buf.st_size;
			}

			/* First, dump the file cache so it is an actual read */
			if (posix_fadvise(fd, 0, filesize, POSIX_FADV_DONTNEED) != 0) {
				perror("fadvise");
				exit(EXIT_FAILURE);
			}
#endif


#if defined(RANDREAD) && !defined(MULTIFILESLOTS)
			position = BUFFER_SIZE * (rand() % slots);
			if (lseek(fd, position, SEEK_SET) != position) {
				perror("lseek");
				exit(EXIT_FAILURE);
			}
#endif

			bytes_read = 0;
			while (bytes_read != BUFFER_SIZE) {
				ssize_t this_read = read(fd, buf + bytes_read, BUFFER_SIZE - bytes_read);
				if (this_read == -1) {
					perror("read");
					exit(EXIT_FAILURE);
				}
				if (this_read == 0)
					break;

				bytes_read += this_read;
			}
			gettimeofday(&end, NULL);
			position += bytes_read;

#ifdef MULTIFILESLOTS
			close(fd);
#endif

			/* Print read latency in ms */
			printf("%lu.%lu ", end.tv_sec, end.tv_usec/1000);
			timersub(&end, &start, &latency);
			printf("%lu\n", (latency.tv_sec * 1000) + (latency.tv_usec / 1000));
			usleep(BETWEENREAD_PAUSE_MS * 1000);
		}

	}
}
