
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-sstartup \
		--iterations $S_STARTUP_ITERATIONS
	return $?
}
