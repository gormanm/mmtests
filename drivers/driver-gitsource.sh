
run_bench() {
	SKIP_SWITCH=
	if [ "$GITSOURCE_SKIP_WARMUP" = "yes" ]; then
		SKIP_SWITCH="--skip-warmup"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-gitsource $SKIP_SWITCH \
		--iterations $GITSOURCE_ITERATIONS

	return $?
}
