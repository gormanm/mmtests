NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-johnripper	\
		--min-threads	$JOHNRIPPER_MIN_THREADS	\
		--max-threads	$JOHNRIPPER_MAX_THREADS	\
		--duration	$JOHNRIPPER_DURATION	\
		--iterations	$JOHNRIPPER_ITERATIONS
	return $?
}
