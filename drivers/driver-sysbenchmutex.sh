
run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-sysbenchmutex \
		--max-threads $SYSBENCHMUTEX_MAX_THREADS	\
		--iterations  $SYSBENCHMUTEX_ITERATIONS
	RETVAL=$?
	return $RETVAL
}
