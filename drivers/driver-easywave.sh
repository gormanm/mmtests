
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-easywave	\
		--min-threads	$EASYWAVE_MIN_THREADS	\
		--max-threads	$EASYWAVE_MAX_THREADS	\
		--iterations	$EASYWAVE_ITERATIONS	\
		--grid		$EASYWAVE_GRID		\
		--source	$EASYWAVE_SOURCE	\
		--modeltime	$EASYWAVE_MODELTIME
	return $?
}
