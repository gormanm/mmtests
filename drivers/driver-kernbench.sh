NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-kernbench \
		--min-threads $KERNBENCH_MIN_THREADS \
		--max-threads $KERNBENCH_MAX_THREADS \
		--iterations $KERNBENCH_ITERATIONS

	return $?
}
