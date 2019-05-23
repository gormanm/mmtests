NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-mlc		\
		--type peak_injection_bandwidth		\
		--iterations $MLC_ITERATIONS
	return $?
}
