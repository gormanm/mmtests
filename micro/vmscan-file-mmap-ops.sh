#!/bin/bash
# Benchmark is just a basic memory pressure. Based on a test suggested by
# Shaohua Li in a bug report complaining about the overhead of measuring
# NR_FREE_PAGES under memory pressure
#
# Copyright Mel Gorman 2010

NUM_CPU=$(grep -c '^processor' /proc/cpuinfo)
NUM_THREADS=${MICRO_VMSCAN_FILE_MMAP_NUM_THREADS:=$NUM_CPU}
MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
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

echo -n > vmscan-file-mmap-ops-$$.pids
cd $SHELLPACK_TEMP || die Failed to cd to temporary directory

ulimit -v $((MICRO_VMSCAN_FILE_MMAP_OPS_SIZE*2/1024))

# Download and build usemem program
# TODO: Get permission to distribute this without external downloads
wget http://www.spinics.net/lists/linux-mm/attachments/gtarazbJaHPaAT.gtar
tar -xf gtarazbJaHPaAT.gtar
mv test/usemem.c .
gcc $BITNESS -lpthread -O2 usemem.c -o usemem || exit -1

# Adjust size for 32-bit if necessary
if [[ `uname -m` =~ i.86 ]]; then
	UNITSIZE=$(($MICRO_VMSCAN_FILE_MMAP_OPS_SIZE / NUM_THREADS))
	while [ $UNITSIZE -gt 1182793728 ]; do
		NUM_THREADS=$((NUM_THREADS+1))
		UNITSIZE=$(($MICRO_VMSCAN_FILE_MMAP_OPS_SIZE / NUM_THREADS))
	done
	echo Thread count $NUM_THREADS for 32-bit
fi

for i in `seq 1 $NUM_THREADS`
do
        create_sparse_file sparse-$i $(($MICRO_VMSCAN_FILE_MMAP_OPS_SIZE / NUM_THREADS))
	echo ./usemem -f sparse-$i -j 4096 $(($MICRO_VMSCAN_FILE_MMAP_OPS_SIZE / NUM_THREADS))
	./usemem -f sparse-$i -j 4096 $(($MICRO_VMSCAN_FILE_MMAP_OPS_SIZE / NUM_THREADS)) &
	echo $! >> vmscan-file-mmap-ops-$$.pids
done

# Wait for memory pressure programs to exit
EXITCODE=0
echo Waiting on helper programs to exit
for PID in `cat vmscan-file-mmap-ops-$$.pids`; do
	wait $PID
	THISCODE=$?
	if [ $THISCODE -ne 0 ]; then
		EXITCODE=$THISCODE
	fi
done

rm vmscan-file-mmap-ops-$$.pids
rm sparse-*
exit $EXITCODE
