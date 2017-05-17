FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-sysbenchthread \
		--max-threads $SYSBENCHTHREAD_MAX_THREADS	\
		--iterations  $SYSBENCHTHREAD_ITERATIONS
	RETVAL=$?
	return $RETVAL
}
