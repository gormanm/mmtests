
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-lmbench-lat_proc	\
		--min-procs	$LMBENCH_LATPROC_MIN_PROCS	\
		--max-procs	$LMBENCH_LATPROC_MAX_PROCS	\
		--iterations	$LMBENCH_LATPROC_ITERATIONS
	return $?
}
