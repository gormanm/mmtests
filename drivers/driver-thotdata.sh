FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-thotdata 	\
		--min-threads $THOTDATA_MIN_THREADS	\
		--max-threads $THOTDATA_MAX_THREADS
	return $?
}
