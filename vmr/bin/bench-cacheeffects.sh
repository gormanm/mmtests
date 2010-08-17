#!/bin/bash

# Paths for results directory and the like
export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
export PATH=$PATH:$SCRIPTDIR
source $SCRIPTDIR/lib/sh/funcs.sh

SELF=$0
FILENAME=
RESULT_DIR=$HOME/vmregressbench-`uname -r`/cacheeffects
NODESIZE_LIST="32 64 128 256 512 1024 2048 4096 64738"
HUGETLBFS_MALLOC=no
EXTRA=
WORDSIZE=`wordsize`

# Print usage of command
usage() {
  echo "bench-cacheeffects.sh (c) Mel Gorman 2005"
  echo "This benchmark can be used to measure various CPU caching effects."
  echo "For exmple, it can show how the cost of array accesses increase when"
  echo "the Working Set Size \(WSS\) exceeds L1 and L2 cache. The WSS are"
  echo "based on powers-of-two. A requested number of samples are taken"
  echo "between each power."
  echo
  echo "Usage: bench-createdelete.sh [options]"
  echo "    -m, --max-powers          The highest power of two used for WSS"
  echo "    -s, --samples             Number of samples between each power"
  echo "    --randomise               Randomise the list access pattern"
  echo "    --libhugetlbfs-lib        Path to libhugetlbfs.so"
  echo "    --use-libhugetlbfs-malloc Use hugepages for the malloc array"
  echo "    -r, --result              Result directory (default: $RESULT_DIR)"
  echo "    -e, --extra               String to append to result dir"
  echo "    -h, --help                Print this help message"
  echo
  exit 0
}

# Parse command line arguements
ARGS=`getopt -o hm:s:r:e: --long help,max-powers:,samples:,randomise,libhugetlbfs-root:,use-libhugetlbfs-malloc,result:,extra:,vmr: -n bench-createdelete.sh -- "$@"`
eval set -- "$ARGS"
while true ; do
	case "$1" in
		-m|--max-powers)
				parse_max_powers $2
				shift 2;;
		-s|--samples)	 SAMPLES="-s $2"; shift 2;;
		-r|--result)	 RESULT_DIR="$2/cacheeffects"; shift 2;;
		-e|--extra)	 EXTRA="$2"; shift 2;;
		-h|--help)	 usage;;
		--randomise)		RANDOMISE="-r"; shift;;
		--libhugetlbfs-root)	LIBHUGETLBFS_ROOT="$2"; shift 2;;
		--use-libhugetlbfs-malloc) HUGETLBFS_MALLOC=yes; shift;;
		*)		shift 1; break;;
	esac
done

if [ "$LIBHUGETLBFS_ROOT" != "" ]; then
	export PATH=$LIBHUGETLBFS_ROOT/bin:$PATH
fi

# Determine if 64-bit is required
check_compile_64bitsize

# Setup the environment for libhugetlbfs if requested
if [ "$HUGETLBFS_MALLOC" = "yes" ]; then
	gethugepagesize
	REQUIRED_HUGEPAGES=$((($LARGEST_ARRAY/$HUGE_PAGESIZE) + 1))
	reserve_hugepages $REQUIRED_HUGEPAGES
	adjust_wss_available_hugepages
fi

# Setup results directory
export RESULT_DIR="$RESULT_DIR$EXTRA"
if [ -d "$RESULT_DIR" ]; then
	reset_hugepages
	die Results dir $RESULT_DIR already exists
fi
mkdir -p $RESULT_DIR || die Failed to create $RESULT_DIR
RESULT="$RESULT_DIR/log.txt"

echo bench-cacheeffects | tee $RESULT
echo o Result directory $RESULT_DIR
echo o Parameters: $MAX_POWERS $SAMPLES $RANDOMISE | tee -a $RESULT
echo o Use hugetlbfs: $HUGETLBFS_MALLOC | tee -a $RESULT
if [ "$HUGETLBFS_MALLOC" = "yes" ]; then
	echo o libhugetlbfs: $LIBHUGETLBFS_ROOT
fi
echo -n "o Randomise: " | tee -a $RESULT
if [ "$RANDOMISE" = "" ]; then
	echo No | tee -a $RESULT
else
	echo Yes | tee -a $RESULT
fi
echo | tee -a $RESULT

# Extract the C program
gettempfile
NODESIZE_LIST="$(($WORDSIZE*2)) $NODESIZE_LIST"
TESTPROGRAM=$TEMPFILE
LINECOUNT=`wc -l $SELF | awk '{print $1}'`
CSTART=`grep -n "BEGIN C FILE" $SELF | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$CSTART)) $SELF > $TESTPROGRAM.c

# Run the program for a variety of node sizes
for NODESIZE in $NODESIZE_LIST; do

	# Work out the size of the padding to make up the requested nodesize
	PADDING=$(($NODESIZE-(2*$WORDSIZE)))
	PADDING=$(($PADDING/$WORDSIZE))

	echo -n "Node size $NODESIZE Padding size $PADDING: " | tee -a $RESULT
	gcc $COMPILE_BITSIZE -Wall -O2 -DPADDING=$PADDING $TESTPROGRAM.c -o $TESTPROGRAM || die Failed to compile cacheeffects.c

	# Run the program with hugetlbfs setup if requested
	HUGECTL=
	if [ "$HUGETLBFS_MALLOC" = "yes" ]; then
		HUGECTL="hugectl --heap --verbose 0"
	fi
	$HUGECTL $TESTPROGRAM -e $MAX_POWERS $SAMPLES $RANDOMISE > $RESULT_DIR/results.$NODESIZE || die Failed to run cacheeffects.c

	# Give some indication of the cost
	tail -1 $RESULT_DIR/results.$NODESIZE | awk '{print $2}' | tee -a $RESULT
done

# Generate a simple gnuplot script
echo -n > $RESULT_DIR/gnuplot.script
echo "set ylabel 'CPU cycles per node'"	>> $RESULT_DIR/gnuplot.script
echo "set xlabel 'working set size"	>> $RESULT_DIR/gnuplot.script
echo "set format x \"2**%g\""		>> $RESULT_DIR/gnuplot.script
echo -n "plot " 			>> $RESULT_DIR/gnuplot.script
FIRST=yes
for PADDING in $PADDING_LIST; do
	if [ "$FIRST" = "no" ]; then
		echo -n ", " >> $RESULT_DIR/gnuplot.script
	fi
	FIRST=no
	echo -n "'results.$PADDING' with lines" >> $RESULT_DIR/gnuplot.script
done
echo >> $RESULT_DIR/gnuplot.script

reset_hugepages
echo | tee -a $RESULT
echo Benchmark completed successfully | tee -a $RESULT
exit 0

==== BEGIN C FILE ====
/*
 * cacheeffects.c
 * This program is used to measure various caching effects based on working
 * set size. At the core is a very basic structure that are stored in a
 * contiguous array. Access to elements is always via linked list to have
 * a single path and traversal type can vary.
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(__i386__)
static inline unsigned long long read_clockcycles(void)
{
	unsigned long long cycles;
	__asm__ volatile ("rdtsc \n\t" : "=A" (cycles));
	return cycles;
}
#endif

#if defined(__x86_64__)
static inline unsigned long long read_clockcycles(void)
{
	unsigned long low_time, high_time;
	asm volatile(
		"rdtsc \n\t" :
			"=a" (low_time),
			"=d" (high_time));
	return ((unsigned long long)high_time << 32) | (low_time);
}
#endif

#if defined(__powerpc__)
static inline unsigned long long read_clockcycles(void)
{
	unsigned long low_time, high_time, tmp;
	asm volatile(
                "0:		\n"
                "mftbu %0	\n"
                "mftb  %1	\n"
                "mftbu %2	\n"
                "cmpw  %2,%0	\n"
                "bne   0b	\n"
                : "=r"(high_time),"=r"(low_time),"=r"(tmp)
                );
	return ((unsigned long long)high_time << 32) | (low_time);
}
#endif

#ifndef PADDING
#define PADDING 0
#endif
struct node {
	struct node *next;
	struct node *prev;
	unsigned long padding[PADDING];
};

void *gcc_optimiser_wibble;
unsigned long long time_traversal(struct node *nodes, unsigned long nelem)
{
	unsigned long long before;
	int i;
	int iters = nelem * 10;

	before = read_clockcycles();
	for (i = 0; i < iters; i++)
		nodes = nodes->next;

	/*
	 * Without this, -O optimises the loop out of existance as the results
	 * go nowhere. This makes read_clockcycles() worthless in the context
	 */
	gcc_optimiser_wibble = nodes;

	return (read_clockcycles() - before) / iters;
}

/* This is a random shuffler based on what on Knuths Volume: 2 */
void randomise_list(struct node *nodes, unsigned long nelem)
{
	struct node *curr, *next;
	struct node *pcurr, *ncurr;
	struct node *pnext, *nnext;
	int j, k;

	/* Verify the list is complete and circular */
	curr = nodes;
	for (j = 0; j < nelem; j++) {
		if (!curr->next) {
			printf("List node is broken %d\n", curr - nodes);
			exit(EXIT_FAILURE);
		}
		curr = curr->next;
	}

	for (j = nelem; j > 1; j--) {
		k = (random() % j);

		curr = &nodes[k];
		next = &nodes[j];
		if (j == k || next->prev == curr || next->next == curr)
			continue;

		pcurr = curr->prev;
		ncurr = curr->next;
		pnext = next->prev;
		nnext = next->next;

		/* Swap the elements */
		pcurr->next = next;
		pnext->next = curr;
		ncurr->prev = next;
		nnext->prev = curr;

		curr->prev = pnext;
		curr->next = nnext;

		next->prev = pcurr;
		next->next = ncurr;
	}
	
#ifdef DEBUG
	/* Verify the list is complete and circular */
	curr = nodes;
	for (j = 0; j <= nelem; j++) {
		if (!curr->next) {
			printf("List node is broken %d\n", curr - nodes);
			exit(EXIT_FAILURE);
		}
		curr = curr->next;
	}
	
	if (curr != nodes) {
		printf("Error in randomising algorithm %d\n", curr - nodes);
		exit(EXIT_FAILURE);
	}
#endif /* DEBUG */
}

struct node *init_nodes(unsigned long nelem)
{
	struct node *nodes;
	size_t size = (size_t)(nelem+1) * sizeof(struct node);
	unsigned long i;

	/* Allocate the array for all the nodes */
	nodes = malloc(size);
	if (nodes == NULL) {
		printf("ERROR: Out of memory\n");
		exit(EXIT_FAILURE);
	}

	/* Initialse the circular linked list */
	nodes[0].prev = &nodes[nelem];
	nodes[0].next = &nodes[1];
	nodes[nelem].prev = &nodes[nelem-1];
	nodes[nelem].next = &nodes[0];
	for (i = 1; i < nelem; i++) {
		nodes[i].prev = &nodes[i-1];
		nodes[i].next = &nodes[i+1];
	}
	nodes[nelem-1].next = &nodes[0];

	return nodes;
}

int main(int argc, char **argv)
{
	int c;
	int powers;
	int pstderr = 0;
	int randomise = 0;
	int samples_per_power = 2;
	int powers_lower = 10, powers_upper = 30;

	while ((c = getopt(argc, argv, "hm:rs:e")) != -1) {
		switch (c) {
		case 'm':
			powers_upper = strtol(optarg, NULL, 10);
			break;
		case 's':
			samples_per_power = strtol(optarg, NULL, 10);
			break;
		case 'r':
			randomise = 1;
			break;
		case 'e':
			pstderr = 1;
			break;
		default:
			break;
		}
	}

	/*
	 * Sizes are based on powers of two. samples_per_power number of
	 * samples are taken between each power for smooth sampling
	 */
	powers_lower *= samples_per_power;
	powers_upper *= samples_per_power;
	for (powers = powers_lower; powers <= powers_upper; powers++) {
		struct node *nodes;
		unsigned long long wss;
		unsigned long long cycles;
		int nelem, sample;

		/* Work out the WSS */
		sample = powers % samples_per_power;
		wss = 1ULL << (powers / samples_per_power);
		wss += (wss / samples_per_power) * sample;

		/* Work out element count and ignore small sizes */
 		nelem = wss / sizeof(struct node);
		if (!nelem)
			continue;

		nodes = init_nodes(nelem);
		if (!nodes)
			continue;

		if (randomise)
			randomise_list(nodes, nelem);

		cycles = time_traversal(nodes, nelem);
		printf("%2.4f %llu\n", (double)powers / samples_per_power, cycles);
		if (pstderr)
			fprintf(stderr, "%2.4f %llu\n", (double)powers / samples_per_power, cycles);

		free(nodes);
	}

	return EXIT_SUCCESS;
}
