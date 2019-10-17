
run_bench() {
	CONFIG_SWITCH=
	TARGET_SWITCH=
	SKIP_SWITCH=
	if [ "$KERNBENCH_CONFIG" != "" ]; then
		CONFIG_SWITCH="--kernel-config $KERNBENCH_CONFIG"
	fi
	if [ "$KERNBENCH_TARGETS" != "" ]; then
		TARGET_SWITCH="--build-targets $KERNBENCH_TARGETS"
	fi
	if [ "$KERNBENCH_SKIP_WARMUP" = "yes" ]; then
		SKIP_SWITCH="--skip-warmup"
	fi

	$SCRIPTDIR/shellpacks/shellpack-bench-kernbench $CONFIG_SWITCH $TARGET_SWITCH $SKIP_SWITCH \
		--min-threads $KERNBENCH_MIN_THREADS \
		--max-threads $KERNBENCH_MAX_THREADS \
		--iterations $KERNBENCH_ITERATIONS

	return $?
}
