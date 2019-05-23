
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-stockfish	\
		--min-threads	$STOCKFISH_MIN_THREADS	\
		--max-threads	$STOCKFISH_MAX_THREADS	\
		--iterations	$STOCKFISH_ITERATIONS
	return $?
}
