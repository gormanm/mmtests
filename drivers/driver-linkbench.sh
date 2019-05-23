
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-linkbench	\
			--warmup-time	$LINKBENCH_WARMUP_TIME \
			--min-threads	$LINKBENCH_MIN_THREADS \
			--max-threads	$LINKBENCH_MAX_THREADS \
			--iterations    $LINKBENCH_ITERATIONS

	return $?
}

