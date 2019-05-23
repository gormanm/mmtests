NAMEEXTRA=

run_bench() {
	rmdir $LOGDIR_RESULTS
	$SCRIPTDIR/shellpacks/shellpack-bench-highalloc \
		--mb-per-sec $HIGHALLOC_ALLOC_RATE \
		--percent $HIGHALLOC_PERCENTAGE \
		--workloads "$HIGHALLOC_WORKLOADS" \
		--gfp-flags $HIGHALLOC_GFPFLAGS
	return $?
}
