#!/bin/bash
#
# This benchmark is based on create/delete test from ext3-tools. The objective
# of this is to check the benefit of the per-cpu allocator. At the time of
# writing, the hot/cold lists are being collapsed into one. This is required
# to see if there is any performance loss from doing that.
#

# Paths for results directory and the like
export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
CPUCOUNT=`grep -c processor /proc/cpuinfo`
FILENAME=
RESULT_DIR=$HOME/vmregressbench-`uname -r`/createdelete
EXTRA=

# The filesizes are set so that the number of allocations
# coming from each CPU steadily rises. The size of the
# actual stride is based on the number of running instances
LOW_FILESIZE=$((4096*$CPUCOUNT))
HIGH_FILESIZE=$((524288*4*$CPUCOUNT))
STRIDE_FILESIZE_PERCPU=4096
ITERATIONS=50

# Print usage of command
usage() {
  echo "bench-createdelete.sh (c) Mel Gorman 2006"
  echo This script measures how well the allocator scales for small file
  echo creations and deletions
  echo
  echo "Usage: bench-createdelete.sh [options]"
  echo "    -f, --filename  Filename prefix to use for test files"
  echo "    -a, --anonymous mmap MAP_ANONYMOUS instead of using a file"
  echo "    -r, --result    Result directory (default: $RESULT_DIR)"
  echo "    -e, --extra     String to append to result dir"
  echo "    -h, --help      Print this help message"
  echo
  exit 1
}

# Parse command line arguements
ARGS=`getopt -o hf:r:e:v:a --long help,filename:,result:,extra:,vmr:,anonymous -n bench-createdelete.sh -- "$@"`
eval set -- "$ARGS"
while true ; do
	case "$1" in
		-f|--filename)	export FILENAME="$2"; shift 2;;
		-a|--anonymous) export ANONYMOUS="yes"; shift;;
		-r|--result)	export RESULT_DIR="$2/createdelete"; shift 2;;
		-e|--extra)	export EXTRA="$2"; shift 2;;
		-h|--help)	usage;;
		*)		shift 1; break;;
	esac
done

# Build the test program that does all the work
SELF=$0
TESTPROGRAM=`mktemp`
LINECOUNT=`wc -l $SELF | awk '{print $1}'`
CSTART=`grep -n "BEGIN C FILE" $SELF | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$CSTART)) $SELF > $TESTPROGRAM.c
gcc $TESTPROGRAM.c -o $TESTPROGRAM || exit 1

# Setup results directory
if [ "$EXTRA" != "" ]; then
  export EXTRA=$EXTRA
fi
export RESULT_DIR=$RESULT_DIR$EXTRA
if [ -d "$RESULT_DIR" ]; then
	echo ERROR: Results dir $RESULT_DIR already exists
	exit 1
fi
mkdir -p $RESULT_DIR || exit

echo bench-createdelete
echo o Result directory $RESULT_DIR

# Setup the filename prefix to be used by the test program
if [ "$ANONYMOUS" = "yes" ]; then
	FILENAME="NULL"
	ITERATIONS=$(($ITERATIONS*5))
else
	if [ "$FILENAME" = "" ]; then
		FILENAME=`mktemp`
	fi
fi

# Run the actual test
MAXINSTANCES=$(($CPUCOUNT*3))
for NUMCPUS in `seq 1 $MAXINSTANCES`; do
	STRIDE_FILESIZE=$(($STRIDE_FILESIZE_PERCPU*$NUMCPUS))
	echo o Running with $NUMCPUS striding $STRIDE_FILESIZE
	SIZE=$LOW_FILESIZE
	while [ $SIZE -lt $HIGH_FILESIZE ]; do
		/usr/bin/time -f "$SIZE %e" $TESTPROGRAM	\
				-n $ITERATIONS			\
				-s $SIZE			\
				-i$NUMCPUS			\
				$FILENAME 2>> $RESULT_DIR/results.$NUMCPUS || exit 1
		tail -1 $RESULT_DIR/results.$NUMCPUS

		# The larger the file gets, the more we want to stride.
		# The smaller sizes are more interesting in a sense as
		# that is where the per-cpu boundaries are. Larger sizes
		# we are just interested in the trends
		MULT=$((1 + ($SIZE/524138)))
		SIZE=$(($SIZE+($STRIDE_FILESIZE*$MULT)))
	done
done

# Generate a simply gnuplot script for giggles
echo -n > $RESULT_DIR/gnuplot.script
echo "set ylabel \"Seconds to create/delete WSS $ITERATIONS times\"" >> $RESULT_DIR/gnuplot.script
echo "set xlabel \"Working Set Size (bytes)\"" >> $RESULT_DIR/gnuplot.script
echo "set format x \"2**%g\""   >> $RESULT_DIR/gnuplot.script
echo -n "plot " 		>> $RESULT_DIR/gnuplot.script
for NUMCPUS in `seq 1 $MAXINSTANCES`; do
	echo -n "'results.$NUMCPUS' using (log(\$1)/log(2)):2 with lines" >> $RESULT_DIR/gnuplot.script
	if [ $NUMCPUS -ne $MAXINSTANCES ]; then
		echo -n ", " >> $RESULT_DIR/gnuplot.script
	fi
done
echo >> $RESULT_DIR/gnuplot.script

exit 0

==== BEGIN C FILE ====
/*
 * This is lifted straight from ext3 tools to test the trunaction of a file.
 * On the suggestion of Andrew Morton, this can be used as a micro-benchmark
 * of the Linux per-cpu allocator. Hence, it has been modified to run the
 * requested number of instances. If scaling properly, the completion times
 * should be the same if the number of instances is less than the number of
 * CPUs.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sched.h>
#include <time.h>
#include <sys/mman.h>
#include <sys/signal.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

int verbose;
char *progname;

void usage(void)
{
	fprintf(stderr, "Usage: %s [-v] [-nN] [-s size] filename-prefix\n", progname);
	fprintf(stderr, "      -v:         Verbose\n"); 
	fprintf(stderr, "     -nN:         Run N iterations\n"); 
	fprintf(stderr, "     -iN:         Run N instances simultaneously\n");
	fprintf(stderr, "     -s size:     Size of file\n"); 
	exit(1);
}

int numcpus(void)
{
	static int count = -1;
	cpu_set_t mask;

	if (count != -1)
		return count;

	/* Work it out for the first time */
	CPU_ZERO(&mask);
	count = 0;
	if (sched_getaffinity(getpid(), sizeof(mask), &mask) == -1) {
		perror("sched_getaffinity\n");
		exit(1);
	}

	while (CPU_ISSET(count, &mask))
		count++;
	
	return count;
}

/* This is the worker function doing all the work */
int createdelete(char *fileprefix, int size, int niters, int instance)
{
	char *buf, *filename;
	int length = strlen(fileprefix) + 6;
	int fd;
	cpu_set_t mask;

	/* Bind to one CPU */
	CPU_ZERO(&mask);
	CPU_SET(instance % numcpus(), &mask);
	if (sched_setaffinity(getpid(), sizeof(cpu_set_t), &mask) == -1) {
		perror("sched_setaffinity");
		exit(1);
	}

	/* Allocate the necessary buffers */
	filename = malloc(length);
	if (filename == 0) {
		perror("nomem");
		exit(1);
	}
	
	if (strcmp(fileprefix, "NULL")) {
		/* Allocate a buffer for writing to the file */
		buf = malloc(size);
		if (buf == 0) {
			perror("nomem");
			exit(1);
		}

		/* Create the file for this instance */
		snprintf(filename, length, "%s-%d\n", fileprefix, instance);
		fd = creat(filename, 0666);
		if (fd < 0) {
			perror("creat");
			exit(1);
		}

		/* Lets get this show on the road */
		while (niters--) {
			if (lseek(fd, 0, SEEK_SET)) {
				perror("lseek");
				exit(1);
			}
			if (write(fd, buf, size) != size) {
				perror("write");
				exit(1);
			}
			if (ftruncate(fd, 0)) {
				perror("ftruncate");
				exit(1);
		}
	}

	} else {
		/* mmap and munmap the mappings */
		while (niters--) {
			/* Create an anonymous mapping */
			buf = mmap(NULL, size,
				PROT_READ|PROT_WRITE,
				MAP_PRIVATE|MAP_ANONYMOUS|MAP_POPULATE,
				-1, 0);
			if (buf == MAP_FAILED) {
				perror("mmap");
				exit(1);
			}

			if (munmap(buf, size) == -1) {
				perror("munmap");
				exit(1);
			}
		}
	}

	exit(0);
}

int main(int argc, char *argv[])
{
	int c;
	int i;
	int ninstances = 1;
	int niters = -1;
	int size = 16 * 4096;
	char *filename;

	progname = argv[0];
	while ((c = getopt(argc, argv, "vn:s:i:")) != -1) {
		switch (c) {
		case 'n':
			niters = strtol(optarg, NULL, 10);
			break;
		case 's':
			size = strtol(optarg, NULL, 10);
			break;
		case 'i':
			ninstances = strtol(optarg, NULL, 10);
			break;
		case 'v':
			verbose++;
			break;
		}
	}

	if (optind == argc)
		usage();
	filename = argv[optind++];
	if (optind != argc)
		usage();

	/* fork off the number of required instances doing work */
	for (i = 0; i < ninstances; i++) {
		pid_t pid = fork();
		if (pid == -1) {
			perror("fork");
			exit(1);
		}

		if (pid == 0)
			createdelete(filename, size / ninstances, niters, i);
	}

	/* Wait for the children */
	for (i = 0; i < ninstances; i++) {
		pid_t pid = wait(NULL);
		if (pid == -1) {
			perror("wait");
			exit(1);
		}
	}

	exit(0);
}

