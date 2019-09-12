
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-autonumabench \
		--iterations $AUTONUMABENCH_ITERATIONS
	return $?
}
