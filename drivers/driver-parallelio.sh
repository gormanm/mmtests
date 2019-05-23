
run_bench() {
	rmdir $LOGDIR_RESULTS
	$SCRIPTDIR/shellpacks/shellpack-bench-parallelio \
		--io-load     $PARALLELIO_IOLOAD \
		--min-io-size $PARALLELIO_MIN_IOSIZE \
		--max-io-size $PARALLELIO_MAX_IOSIZE \
		--workloads "$PARALLELIO_WORKLOADS" \
		--workload-duration $PARALLELIO_WORKLOAD_DURATION
	return $?
}
