#!/bin/bash
# Copyright Mel Gorman 2012

SELF=$0
SINGLE_MAPPING_SIZE=$1
PERCENTAGE_ANON=$2

MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
TOTAL_MAPPING_SIZE=$((MEMTOTAL_BYTES))
NUM_THREADS=$((TOTAL_MAPPING_SIZE/SINGLE_MAPPING_SIZE))

BITNESS=-m64
case `uname -m` in
i?86)
	BITNESS=
esac

function create_sparse_file() {
	TITLE=$1
	SIZE=$2

	echo Creating sparse file $TITLE
	dd if=/dev/zero of=$TITLE bs=4096 count=0 seek=$((SIZE/4096+1))
}

if [ "$VM_TRANSPARENT_HUGEPAGES_DEFAULT" != "always" ]; then
	echo This test is primarily aimed at THP and compaction interaction
	exit -1
fi

echo -n > compaction-parallel-$$.pids
cd $SHELLPACK_TEMP || die Failed to cd to temporary directory

# Download and build usemem program
# TODO: Get permission to distribute this without external downloads
wget http://www.spinics.net/lists/linux-mm/attachments/gtarazbJaHPaAT.gtar
tar -xf gtarazbJaHPaAT.gtar
mv test/usemem.c .
gcc $BITNESS -lpthread -O2 usemem.c -o usemem || exit -1

MEMTOTAL_ANON=$((TOTAL_MAPPING_SIZE*PERCENTAGE_ANON/100))
MEMTOTAL_FILE=$((TOTAL_MAPPING_SIZE*(100-PERCENTAGE_ANON)/100))
NR_THREADS_FILE=$((NUM_THREADS*(100-PERCENTAGE_ANON)/100))
NR_THREADS_ANON=$((NUM_THREADS-NR_THREADS_FILE))

ulimit -v $((MEMTOTAL_BYTES/1024))


START_TIME=`date +%s`
END_TIME=$((START_TIME+180))


ITERATION=0
while [ `date +%s` -lt $END_TIME ]; do
	create_sparse_file sparse-$ITERATION $TOTAL_MAPPING_SIZE

	echo
	echo Total memory to consume: $TOTAL_MAPPING_SIZE
	echo Anonymous memory: $MEMTOTAL_ANON
	echo File-backed memory: $MEMTOTAL_FILE

	if [ $NR_THREADS_FILE -gt 0 ]; then
		echo ./usemem -f sparse-$ITERATION -j 4096 -n $NR_THREADS_FILE --readonly $((MEMTOTAL_FILE/NR_THREADS_FILE))
		./usemem -f sparse-$ITERATION -j 4096 -n $NR_THREADS_FILE --readonly $((MEMTOTAL_FILE/NR_THREADS_FILE)) &
		echo $! >> compaction-parallel-$$.pids
	fi

	echo ./usemem -j 4096 -n $NR_THREADS_ANON $((MEMTOTAL_ANON / NR_THREADS_ANON))
	./usemem -j 4096 -n $NR_THREADS_ANON $((MEMTOTAL_ANON / NR_THREADS_ANON)) &
	echo $! >> compaction-parallel-$$.pids

	# Wait for memory pressure programs to exit
	echo Waiting on helper programs to exit
	for PID in `cat compaction-parallel-$$.pids`; do
		wait $PID
	done
	rm sparse-$ITERATION
	ITERATION=$((ITERATION+1))
done

rm compaction-parallel-$$.pids
rm sparse-*
exit 0
