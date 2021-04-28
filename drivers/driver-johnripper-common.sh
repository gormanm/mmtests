$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh johnripper

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-johnripper	\
		--min-threads	$JOHNRIPPER_MIN_THREADS	\
		--max-threads	$JOHNRIPPER_MAX_THREADS	\
		--duration	$JOHNRIPPER_DURATION	\
		--hash		$JOHNRIPPER_HASH	\
		--iterations	$JOHNRIPPER_ITERATIONS
	return $?
}
