#!/bin/bash
# Benchmark is just a basic memory pressure. Based on a test suggested by
# Shaohua Li in a bug report complaining about the overhead of measuring
# NR_FREE_PAGES under memory pressure
#
# Copyright Mel Gorman 2010
NUM_CPU=$(grep -c '^processor' /proc/cpuinfo)
NUM_THREADS=${MICRO_VMSCAN_NUM_THREADS:=$NUM_CPU}
MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
PERCENTAGE_ANON=$MICRO_VMSCAN_MIXED_ANON_PERCENTAGE
DURATION=${MICRO_VMSCAN_DURATION:-300}
MICRO_VMSCAN_MIXED_MMAPREAD_ITER=${MICRO_VMSCAN_MIXED_MMAPREAD_ITER:-10}

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

function create_populated_file() {
	TITLE=$1
	SIZE=$2

	echo Creating populated file $TITLE
	dd if=/dev/zero of=$TITLE bs=4096 count=0 count=$((SIZE/4096+1))
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
if [[ `uname -m` =~ i.86 ]]; then
	UNITSIZE=$((MICRO_VMSCAN_MIXED_MMAP_SIZE / NUM_THREADS))
	while [ $UNITSIZE -gt 1182793728 ]; do
		NUM_THREADS=$((NUM_THREADS+1))
		UNITSIZE=$((MICRO_VMSCAN_MIXED_MMAP_SIZE / NUM_THREADS))
	done
	echo Thread count $NUM_THREADS for 32-bit
fi

MEMTOTAL_ANON=$((MICRO_VMSCAN_MIXED_MMAP_SIZE*PERCENTAGE_ANON/100))
MEMTOTAL_FILE=$((MICRO_VMSCAN_MIXED_MMAP_SIZE*(100-PERCENTAGE_ANON)/100))

# If the test is for both anon and file then split the thread counts
if [ $MEMTOTAL_ANON -gt 0 -a $MEMTOTAL_FILE -gt 0 ]; then
	NUM_THREADS=$((NUM_THREADS/2))
	if [ $NUM_THREADS -eq 0 ]; then
		NUM_THREADS=1
	fi
fi

ulimit -v $((MICRO_VMSCAN_MIXED_MMAP_SIZE/1024))

if [ $MEMTOTAL_FILE -gt 0 ]; then
	echo Creating files
	for THREAD in `seq 1 $NUM_THREADS`; do
		if [ "$READONLY" != "" ]; then
			echo create_sparse_file sparse-$THREAD $((MEMTOTAL_FILE / NUM_THREADS))
			create_sparse_file sparse-$THREAD $((MEMTOTAL_FILE / NUM_THREADS))
		else
			echo create_populated_file sparse-$THREAD $((MEMTOTAL_FILE / NUM_THREADS))
			create_populated_file sparse-$THREAD $((MEMTOTAL_FILE / NUM_THREADS))
		fi
	done
fi

STARTTIME=`date +%s`
ENDTIME=$((STARTTIME+300))
CURRENT_TIME=$STARTTIME
echo Creating threads
for THREAD in `seq 1 $NUM_THREADS`; do
	if [ $MEMTOTAL_FILE -gt 0 ]; then
		echo ./usemem -f sparse-$THREAD -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER)) $READONLY $(($MEMTOTAL_FILE / NUM_THREADS))
		./usemem -f sparse-$THREAD -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER)) $READONLY $(($MEMTOTAL_FILE / NUM_THREADS)) 2> /dev/null &
		file_procs[$THREAD]=$!
	fi

	if [ $MEMTOTAL_ANON -gt 0 ]; then
		echo ./usemem -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER)) $READONLY $((MEMTOTAL_ANON / NUM_THREADS))
		./usemem -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER)) $READONLY $((MEMTOTAL_ANON / NUM_THREADS)) > /dev/null &
		anon_procs[$THREAD]=$!
	fi
done

EXIT_CODE=$SHELLPACK_SUCCESS

while [ $CURRENT_TIME -lt $ENDTIME ]; do
	for THREAD in `seq 1 $NUM_THREADS`; do
		if [ $MEMTOTAL_FILE -gt 0 ]; then
			ps -p ${file_procs[$THREAD]} > /dev/null
			if [ $? -ne 0 ]; then
				# Watch for errors in usemem but allow test to continue
				# running and report it later
				wait ${file_procs[$THREAD]} 
				if [ $? -ne 0 ]; then
					EXIT_CODE=$SHELLPACK_ERROR
				fi
				echo ./usemem -f sparse-$THREAD -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER)) $READONLY $(($MEMTOTAL_FILE / NUM_THREADS))
				./usemem -f sparse-$THREAD -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER)) $READONLY $(($MEMTOTAL_FILE / NUM_THREADS)) > /dev/null &
				file_procs[$THREAD]=$!
				MICRO_VMSCAN_MIXED_MMAPREAD_ITER=$((MICRO_VMSCAN_MIXED_MMAPREAD_ITER*2))
			fi
		fi

		if [ $MEMTOTAL_ANON -gt 0 ]; then
			ps -p ${anon_procs[$THREAD]} > /dev/null
			if [ $? -ne 0 ]; then
				# Watch for errors in usemem similar as for files
				wait ${anon_procs[$THREAD]} 
				if [ $? -ne 0 ]; then
					EXIT_CODE=$SHELLPACK_ERROR
				fi

				echo ./usemem -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER*2)) $READONLY $((MEMTOTAL_ANON / NUM_THREADS))
				./usemem -j 4096 -r $((MICRO_VMSCAN_MIXED_MMAPREAD_ITER*2)) $READONLY $((MEMTOTAL_ANON / NUM_THREADS)) > /dev/null &
				anon_procs[$THREAD]=$!
				MICRO_VMSCAN_MIXED_MMAPREAD_ITER=$((MICRO_VMSCAN_MIXED_MMAPREAD_ITER*2))
			fi
		fi
	done

	sleep 5
	CURRENT_TIME=`date +%s`
done

if [ "$MICRO_VMSCAN_MIXED_MMAPREAD_NOKILL" = "yes" ]; then
	# If requested, wait for all threads to exit and check their code
	for THREAD in `seq 1 $NUM_THREADS`; do
		if [ $MEMTOTAL_FILE -gt 0 ]; then
			wait ${file_procs[$THREAD]}
			if [ $? -ne 0 ]; then
				EXIT_CODE=$SHELLPACK_ERROR
			fi
		fi
		if [ $MEMTOTAL_ANON -gt 0 ]; then
			wait ${anon_procs[$THREAD]}
			if [ $? -ne 0 ]; then
				EXIT_CODE=$SHELLPACK_ERROR
			fi
		fi
	done
else
	# Otherwise, just exit quickly as possible
	for THREAD in `seq 1 $NUM_THREADS`; do
		kill -9 ${file_procs[$THREAD]}
		kill -9 ${anon_procs[$THREAD]}
	done
fi

rm sparse-*
exit $EXIT_CODE
