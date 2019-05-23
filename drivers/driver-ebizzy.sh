NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-ebizzy \
		--max-threads $EBIZZY_MAX_THREADS \
		--iterations $EBIZZY_ITERATIONS \
		--duration $EBIZZY_DURATION
	return $?
}
