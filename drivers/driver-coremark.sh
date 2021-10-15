
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-coremark \
		--iterations $COREMARK_ITERATIONS      \
		--threads    $COREMARK_THREADS

	return $?
}
