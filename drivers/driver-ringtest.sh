FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	if [ "$RINGTEST_MAX_TASKS" -gt 1000 ]; then
		RINGTEST_MAX_TASKS=1000
	fi

	$SCRIPTDIR/shellpacks/shellpack-bench-ringtest \
		--min-tasks  $RINGTEST_MIN_TASKS \
		--max-tasks  $RINGTEST_MAX_TASKS \
		--iterations $RINGTEST_ITERATIONS
	return $?
}
