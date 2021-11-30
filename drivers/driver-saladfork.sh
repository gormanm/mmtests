run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-saladfork \
		--iterations $SALADFORK_ITERATIONS
	return $?
}
