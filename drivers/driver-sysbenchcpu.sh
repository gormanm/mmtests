FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-sysbenchcpu \
		--max-prime   $SYSBENCHCPU_MAX_PRIME		\
		--max-threads $SYSBENCHCPU_MAX_THREADS		\
		--iterations  $SYSBENCHCPU_ITERATIONS
	RETVAL=$?
	return $RETVAL
}
