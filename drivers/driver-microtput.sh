NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-microtput \
		--min-threads $MICROTPUT_MIN_THREADS \
		--max-threads $MICROTPUT_MAX_THREADS \
		--iterations  $MICROTPUT_ITERATIONS
	return $?
}
