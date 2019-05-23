
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-schbench \
		--message-threads $SCHBENCH_MESSAGE_THREADS \
		--threads $SCHBENCH_THREADS \
		--runtime $SCHBENCH_RUNTIME
	return $?
}
