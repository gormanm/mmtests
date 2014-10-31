FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-filebench \
		--personality	$FILEBENCH_PERSONALITY	\
		--iterations	$FILEBENCH_ITERATIONS 	\
		--working-set	$FILEBENCH_WORKING_SET	\
		--min-threads	$FILEBENCH_MIN_THREADS	\
		--max-threads	$FILEBENCH_MAX_THREADS
	return $?
}
