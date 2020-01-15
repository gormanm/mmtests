run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-spinplace	\
		--duration $SPINPLACE_DURATION		\
		--iterations $SPINPLACE_ITERATIONS
	return $?
}
