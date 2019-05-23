
run_bench() {
	DIRECT_IO_PARAM=
	if [ "$FILEBENCH_DIRECT_IO" = "yes" ]; then
		DIRECT_IO_PARAM=--direct-io
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-filebench $DIRECT_IO_PARAM \
		--personality	$FILEBENCH_PERSONALITY	\
		--iterations	$FILEBENCH_ITERATIONS 	\
		--working-set	$FILEBENCH_WORKING_SET	\
		--min-threads	$FILEBENCH_MIN_THREADS	\
		--max-threads	$FILEBENCH_MAX_THREADS
	return $?
}
