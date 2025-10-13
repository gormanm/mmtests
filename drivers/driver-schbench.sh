
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-schbench \
		--messangers	 $SCHBENCH_MESSAGE_THREADS	\
		--min-workers	 $SCHBENCH_MIN_WORKER_THREADS	\
		--max-workers    $SCHBENCH_MAX_WORKER_THREADS	\
		--interval	 $SCHBENCH_INTERVAL		\
		--runtime	 $SCHBENCH_RUNTIME
	return $?
}
