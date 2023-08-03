
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-gnupgsource 				\
		${GNUPGSOURCE_SKIP_WARMUP:+--skip-warmup}				\
		${GNUPGSOURCE_ITERATIONS:+--iterations "${GNUPGSOURCE_ITERATIONS}"}

	return $?
}
