
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-poundtime 	\
		--min-threads $POUNDTIME_MIN_THREADS	\
		--max-threads $POUNDTIME_MAX_THREADS	\
		--iterations  $POUNDTIME_ITERATIONS
	return $?
}
