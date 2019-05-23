NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-dedup \
		--min-threads $DEDUP_MIN_THREADS \
		--max-threads $DEDUP_MAX_THREADS \
		--iterations $DEDUP_ITERATIONS \
		--file $DEDUP_FILE
	return $?
}
