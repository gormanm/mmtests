FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	DVDSTORE_SCALE_COMMAND=

	if [ "$DVDSTORE_WORKLOAD_SIZE" != "" ]; then
		DVDSTORE_SCALE_COMMAND="--workload-size $DVDSTORE_WORKLOAD_SIZE"
	fi

	if [ $DVDSTORE_MAX_THREADS -gt 96 ]; then
		DVDSTORE_MAX_THREADS=96
	fi

	eval $SHELLPACK_INCLUDE/shellpack-bench-dvdstore \
		$DVDSTORE_SCALE_COMMAND \
		--dbdriver $DVDSTORE_DRIVER \
		--shared-buffers $OLTP_SHAREDBUFFERS \
		--effective-cachesize $OLTP_CACHESIZE \
		--warmup-time $DVDSTORE_WARMUP_TIME \
		--run-time $DVDSTORE_RUN_TIME \
		--max-threads $DVDSTORE_MAX_THREADS
	return $?
}
