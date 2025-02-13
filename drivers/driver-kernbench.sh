
run_bench() {
	VERSION_SWITCH=
	if [ "$KERNBENCH_VERSION" != "" ]; then
		VERSION_SWITCH="-v $KERNBENCH_VERSION"
	fi

	$SCRIPTDIR/shellpacks/shellpack-bench-kernbench 	 		\
		${KERNBENCH_CONFIG:+--kernel-config "$KERNBENCH_CONFIG"}	\
		${KERNBENCH_TARGETS:+--build-targets "$KERNBENCH_TARGETS"}	\
		${KERNBENCH_VERSION:+-v "$KERNBENCH_VERSION"}			\
		--min-threads $KERNBENCH_MIN_THREADS				\
		--max-threads $KERNBENCH_MAX_THREADS				\
		--iterations $KERNBENCH_ITERATIONS

	return $?
}
