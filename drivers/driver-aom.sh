run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-aom		\
		--min-threads	$AOM_MIN_THREADS	\
		--max-threads	$AOM_MAX_THREADS
	return $?
}
