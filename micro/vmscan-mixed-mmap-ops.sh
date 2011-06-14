#!/bin/bash
# Benchmark is just a basic memory pressure. Based on a test suggested by
# Shaohua Li in a bug report complaining about the overhead of measuring
# NR_FREE_PAGES under memory pressure
#
# Copyright Mel Gorman 2010
NUM_CPU=$(grep -c '^processor' /proc/cpuinfo)
NUM_THREADS=${MICRO_VMSCAN_MIXED_MMAP_NUM_THREADS:=$NUM_CPU}
OUTER_ITER=${MICRO_VMSCAN_MIXED_MMAP_OPS_OUTER_ITER:=1}
MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
PERCENTAGE_ANON=$MICRO_VMSCAN_MIXED_ANON_PERCENTAGE
SELF=$0
READONLY=$1
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


echo -n > vmscan-mixed-mmap-ops-$$.pids
cd $SHELLPACK_TEMP || die Failed to cd to temporary directory

# Download and build usemem program
# TODO: Get permission to distribute this without external downloads
wget http://www.spinics.net/lists/linux-mm/attachments/gtarazbJaHPaAT.gtar
tar -xf gtarazbJaHPaAT.gtar
mv test/usemem.c .
gcc $BITNESS -lpthread -O2 usemem.c -o usemem || exit -1

# Adjust size for 32-bit if necessary
if [[ `uname -m` =~ i?86 ]]; then
	UNITSIZE=$((MICRO_VMSCAN_MIXED_MMAPREAD_SIZE / NUM_THREADS))
	while [ $UNITSIZE -gt 1182793728 ]; do
		NUM_THREADS=$((NUM_THREADS+1))
		UNITSIZE=$((MICRO_VMSCAN_MIXED_MMAPREAD_SIZE / NUM_THREADS))
	done
	echo Thread count $NUM_THREADS for 32-bit
fi

MEMTOTAL_ANON=$((MICRO_VMSCAN_MIXED_MMAPREAD_SIZE*PERCENTAGE_ANON/100))
MEMTOTAL_FILE=$((MICRO_VMSCAN_MIXED_MMAPREAD_SIZE*(100-PERCENTAGE_ANON)/100))

ulimit -v $((MICRO_VMSCAN_MIXED_MMAPREAD_SIZE/1024))

for OUTER in `seq 1 $MICRO_VMSCAN_MIXED_MMAP_OPS_OUTER_ITER`; do
echo
echo Total memory to consume: $MICRO_VMSCAN_MIXED_MMAPREAD_SIZE
echo Anonymous memory: $MEMTOTAL_ANON
echo File-backed memory: $MEMTOTAL_FILE

echo Creating files
for i in `seq 1 $NUM_THREADS`
do
	create_sparse_file sparse-$i $((MEMTOTAL_FILE / NUM_THREADS))
done

# Fire up file mappings
for i in `seq 1 $NUM_THREADS`
do
	echo ./usemem -f sparse-$i -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER*2)) $READONLY $(($MEMTOTAL_FILE / NUM_THREADS))
	./usemem -f sparse-$i -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER*2)) $READONLY $(($MEMTOTAL_FILE / NUM_THREADS)) &
	echo $! >> vmscan-mixed-mmap-ops-$$.pids
done

# Fire up anonymous mappings
for i in `seq 1 $NUM_THREADS`
do
	echo ./usemem -j 4096 -r $MICRO_VMSCAN_MIXED_MMAPREAD_ITER $READONLY $((MEMTOTAL_ANON / NUM_THREADS))
	./usemem -j 4096 -r $MICRO_VMSCAN_MIXED_MMAPREAD_ITER $READONLY $((MEMTOTAL_ANON / NUM_THREADS)) &
	echo $! >> vmscan-mixed-mmap-ops-$$.pids
done

# Wait for memory pressure programs to exit
EXITCODE=0
echo Waiting on helper programs to exit
for PID in `cat vmscan-mixed-mmap-ops-$$.pids`; do
	wait $PID
	THISCODE=$?
	if [ $THISCODE -ne 0 ]; then
		EXITCODE=$THISCODE
	fi
done

rm vmscan-mixed-mmap-ops-$$.pids
rm sparse-*
done
exit $EXITCODE
