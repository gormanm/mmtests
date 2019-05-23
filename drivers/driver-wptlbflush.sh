
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-wptlbflush \
		--min-processes $WPTLBFLUSH_MIN_PROCESSES \
		--max-processes $WPTLBFLUSH_MAX_PROCESSES
	return $?
}
