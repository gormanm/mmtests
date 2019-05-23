
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-S-startup \
		--iterations $S_STARTUP_ITERATIONS
	return $?
}
