
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-schbench \
		${SCHBENCH_DISABLE_SPINLOCK:+--disable-spinlock}				\
		${SCHBENCH_MESSENGER_PIN:+--messenger-pin "$SCHBENCH_MESSENGER_PIN"}		\
		${SCHBENCH_THINKTIME_OPS:+--thinktime-ops "$SCHBENCH_THINKTIME_OPS"}		\
		${SCHBENCH_THINKTIME_SLEEP:+--thinktime-sleep "$SCHBENCH_THINKTIME_SLEEP"}	\
		--messengers	 $SCHBENCH_MESSAGE_THREADS					\
		--min-workers	 $SCHBENCH_MIN_WORKER_THREADS					\
		--max-workers    $SCHBENCH_MAX_WORKER_THREADS					\
		--interval	 $SCHBENCH_INTERVAL						\
		--runtime	 $SCHBENCH_RUNTIME
	return $?
}
