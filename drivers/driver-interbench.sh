FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-interbench	\
		--min-threads $INTERBENCH_MIN_THREADS	\
		--max-threads $INTERBENCH_MAX_THREADS	\
		--duration    $INTERBENCH_DURATION
	return $?
}
