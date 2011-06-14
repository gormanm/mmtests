#!/bin/bash
# Benchmark is just a basic memory pressure. Based on a test suggested by
# Shaohua Li in a bug report complaining about the overhead of measuring
# NR_FREE_PAGES under memory pressure
#
# Copyright Mel Gorman 2010

NUM_CPU=$(grep -c '^processor' /proc/cpuinfo)
NUM_THREADS=${MICRO_VMSCAN_ANON_MMAP_NUM_THREADS:=$NUM_CPU}
MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
SELF=$0
READONLY=$1
BITNESS=-m64
case `uname -m` in
i?86)
	BITNESS=
esac

echo -n > vmscan-anon-mmap-ops-$$.pids
cd $SHELLPACK_TEMP || die Failed to cd to temporary directory

# Download and build usemem program
# TODO: Get permission to distribute this without external downloads
wget http://www.spinics.net/lists/linux-mm/attachments/gtarazbJaHPaAT.gtar
tar -xf gtarazbJaHPaAT.gtar
mv test/usemem.c .
gcc $BITNESS -lpthread -O2 usemem.c -o usemem || exit -1

# Adjust size for 32-bit if necessary
if [[ `uname -m` =~ i?86 ]]; then
	UNITSIZE=$(($MICRO_VMSCAN_ANON_MMAP_OPS_SIZE / NUM_THREADS))
	while [ $UNITSIZE -gt 1182793728 ]; do
		NUM_THREADS=$((NUM_THREADS+1))
		UNITSIZE=$(($MICRO_VMSCAN_ANON_MMAP_OPS_SIZE / NUM_THREADS))
	done
	echo Thread count $NUM_THREADS for 32-bit
fi

for i in `seq 1 $NUM_THREADS`
do
	echo ./usemem -j 4096 -r $MICRO_VMSCAN_ANON_MMAP_OPS_ITER $READONLY $(($MICRO_VMSCAN_ANON_MMAP_OPS_SIZE / NUM_THREADS))
	./usemem -j 4096 -r $MICRO_VMSCAN_ANON_MMAP_OPS_ITER $READONLY $(($MICRO_VMSCAN_ANON_MMAP_OPS_SIZE / NUM_THREADS)) &
	echo $! >> vmscan-anon-mmap-ops-$$.pids
done

# Wait for memory pressure programs to exit
EXITCODE=0
echo Waiting on helper programs to exit
for PID in `cat vmscan-anon-mmap-ops-$$.pids`; do
	wait $PID
	THISCODE=$?
	if [ $THISCODE -ne 0 ]; then
		EXITCODE=$THISCODE
	fi
done

rm vmscan-anon-mmap-ops-$$.pids
rm sparse-*
exit $EXITCODE
