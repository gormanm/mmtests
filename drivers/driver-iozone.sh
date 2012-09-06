FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	if [ "$IOZONE_SIZE" != "" ]; then
		IOZONE_SIZE="--filesize $((IOZONE_SIZE/1024))"
	fi
	if [ "$IOZONE_RECORD_LEN" != "" ]; then
		IOZONE_RECORD_LEN="--record-length $IOZONE_RECORD_LEN"
	fi
	if [ "$IOZONE_THREADS" != "" ]; then
		IOZONE_THREADS="--threads $IOZONE_THREADS"
	fi
	if [ "$IOZONE_FLUSH" = "yes" ]; then
		IOZONE_FLUSH=--flush
	fi
	if [ "$IOZONE_SHOW_THREAD_THROUGHPUT" = "yes" ]; then
		IOZONE_SHOW_THREAD_THROUGHPUT=--show-thread-throughput
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-iozone $IOZONE_RELATIVE_SIZE $IOZONE_SIZE $IOZONE_RECORD_LEN $IOZONE_THREADS $IOZONE_FLUSH $IOZONE_SHOW_THREAD_THROUGHPUT $IOZONE_TEST_TYPE
	return $?
}
