
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-xsbench				\
		${XSBENCH_MIN_THREADS:+--min-threads "${XSBENCH_MIN_THREADS}"}	\
		${XSBENCH_MAX_THREADS:+--max-threads "${XSBENCH_MAX_THREADS}"}	\
		${XSBENCH_ITERATIONS:+--iterations "${XSBENCH_ITERATIONS}"}	\
		${XSBENCH_MODEL:+--parallel-model "${XSBENCH_MODEL}"}		\
		${XSBENCH_SIZE:+--size "${XSBENCH_SIZE}"}
	return $?
}
