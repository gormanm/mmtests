FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-linkbench	\
			--warmup-time	$LINKBENCH_WARMUP_TIME \
			--min-threads	$LINKBENCH_MIN_THREADS \
			--max-threads	$LINKBENCH_MAX_THREADS \
			--workload-size $LINKBENCH_WORKLOAD_SIZE \
			--iterations    $LINKBENCH_ITERATIONS

	return $?
}

