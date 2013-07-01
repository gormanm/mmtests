FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	rmdir $LOGDIR_RESULTS
	$SCRIPTDIR/shellpacks/shellpack-bench-stress-highalloc \
		--mb-per-sec $HIGHALLOC_ALLOC_RATE \
		--percent $HIGHALLOC_PERCENTAGE \
		-z
	return $?
}
