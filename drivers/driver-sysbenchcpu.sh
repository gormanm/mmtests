
run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-sysbenchcpu \
		--max-prime   $SYSBENCHCPU_MAX_PRIME		\
		--min-threads $SYSBENCHCPU_MIN_THREADS		\
		--max-threads $SYSBENCHCPU_MAX_THREADS		\
		--iterations  $SYSBENCHCPU_ITERATIONS
	RETVAL=$?
	return $RETVAL
}
