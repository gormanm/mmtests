
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-poundsyscall	\
		--min-threads $POUNDSYSCALL_MIN_THREADS	\
		--max-threads $POUNDSYSCALL_MAX_THREADS	\
		--iterations  $POUNDSYSCALL_ITERATIONS
	return $?
}
