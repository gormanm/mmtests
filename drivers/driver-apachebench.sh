$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh apachebuild

run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-apachebench \
		--min-clients $APACHEBENCH_MIN_CLIENTS \
		--max-clients $APACHEBENCH_MAX_CLIENTS \
		--iterations  $APACHEBENCH_ITERATIONS

	return $?
}
