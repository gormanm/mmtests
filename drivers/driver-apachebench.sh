
run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-apachebench \
		--min-clients $APACHEBENCH_MIN_CLIENTS \
		--max-clients $APACHEBENCH_MAX_CLIENTS \
		--iterations  $APACHEBENCH_ITERATIONS

	return $?
}
