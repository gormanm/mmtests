$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh lkp

run_bench() {

	$SHELLPACK_INCLUDE/shellpack-bench-lkp 		\
		--workload $LKP_WORKLOAD		\
		--min-threads $LKP_MIN_THREADS		\
		--max-threads $LKP_MAX_THREADS		\
		--duration $LKP_DURATION		\
		--iterations $LKP_ITERATIONS

	return $?
}
