NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-hackbench \
		--$IPCMETHOD \
		--min-groups $HACKBENCH_MIN_GROUPS \
		--max-groups $HACKBENCH_MAX_GROUPS \
		--type       $HACKBENCH_TYPE       \
		--iterations $HACKBENCH_ITERATIONS
	return $?
}
