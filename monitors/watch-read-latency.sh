#!/bin/bash
# This monitor reads a file in a continual loop recording the latency
# of a read. Users complain that interactive performance can floor
# in certain circumstances like when writing to USB. In extreme cases,
# music jitter is reported. This program vagely simulates reading a
# music file but jitter in it could also imply problems with accessing
# config files
# 
# (c) Mel Gorman 2012

# Build the reader program
TEMPFILE=`mktemp`
LINECOUNT=`wc -l $0 | awk '{print $1}'`
CSTART=`grep -n "BEGIN C FILE" $0 | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$CSTART)) $0 | grep -v "^###" > $TEMPFILE.c
gcc -O2 $TEMPFILE.c -o $TEMPFILE || exit -1

# Build a file on local storage for the program to access
dd if=/dev/zero of=monitor_readfile ibs=1048576 count=100 > /dev/null 2> /dev/null

# Start the reader
$TEMPFILE monitor_readfile &
READER_PID=$!

# Handle being shutdown
EXITING=0
shutdown_read() {
	kill -9 $READER_PID
	rm $TEMPFILE
	rm monitor_readfile
	EXITING=1
	exit 0
}
	
trap shutdown_read TERM
trap shutdown_read INT

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

	/* Read until interrupted */
	while (1) {
		ssize_t position;
		ssize_t bytes_read;
		ssize_t slots_read;
		struct timeval start, end, latency;

		/* First, dump the file cache so it's an actual read */
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
		
		/* Read whole file measuring the latency of each access */
		while (slots_read++ < slots) {
#ifdef RANDREAD
			position = BUFFER_SIZE * (rand() % slots);
			if (lseek(fd, position, SEEK_SET) != position) {
				perror("lseek");
				exit(EXIT_FAILURE);
			}
#endif

			gettimeofday(&start, NULL);
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

			/* Print read latency in ms */
			printf("%lu.%lu ", end.tv_sec, end.tv_usec/1000);
			timersub(&end, &start, &latency);
			printf("%lu\n", (latency.tv_sec * 1000) + (latency.tv_usec / 1000));
			usleep(BETWEENREAD_PAUSE_MS * 1000);
		}
	}
}
