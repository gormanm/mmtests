run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-pedsort \
		--min-threads $PEDSORT_MIN_THREADS \
		--max-threads $PEDSORT_MAX_THREADS \
		--iterations $PEDSORT_ITERATIONS \
		--nfiles $PEDSORT_NFILES \
		--nwords-file $PEDSORT_NFILES_WORDS \
		--cache $PEDSORT_CACHE \
		--tmpfs $PEDSORT_TMPFS

	return $?
}
