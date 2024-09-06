
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-ebizzy \
		--min-threads $EBIZZY_MIN_THREADS \
		--max-threads $EBIZZY_MAX_THREADS \
		--iterations $EBIZZY_ITERATIONS \
		--duration $EBIZZY_DURATION
	return $?
}
