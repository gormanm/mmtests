NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-timedmunlock \
		--alloc-gb "$TIMEDMUNLOCK_ALLOC_GB"        \
		--iterations "$TIMEDMUNLOCK_ITERATIONS"

	return $?
}
