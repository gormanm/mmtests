
run_bench() {
	SKIP_SWITCH=
	if [ "$GNUPGSOURCE_SKIP_WARMUP" = "yes" ]; then
		SKIP_SWITCH="--skip-warmup"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-gnupgsource $SKIP_SWITCH \
		--iterations $GNUPGSOURCE_ITERATIONS

	return $?
}
