
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-thpscale 	\
		--min-threads $THPSCALE_MIN_THREADS	\
		--max-threads $THPSCALE_MAX_THREADS	\
		--mapsize     $THPSCALE_MAPSIZE
	return $?
}
