FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-pbzip2bench \
		--min-threads $PBZIP2BENCH_MIN_THREADS \
		--max-threads $PBZIP2BENCH_MAX_THREADS \
		--iterations $PBZIP2BENCH_ITERATIONS \
		--file $PBZIP2BENCH_FILE
	return $?
}
