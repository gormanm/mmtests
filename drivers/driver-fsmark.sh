run_bench() {
	FSMARK_NR_TOP_DIRECTORIES=${FSMARK_NR_TOP_DIRECTORIES:-nr_threads}
	FSMARK_SYNCMODE=${FSMARK_SYNCMODE:-0}
	$SHELLPACK_INCLUDE/shellpack-bench-fsmark			\
		--min-threads $FSMARK_MIN_THREADS			\
		--max-threads $FSMARK_MAX_THREADS			\
		--filesize $FSMARK_FILESIZE				\
		--nr-files-per-iteration $FSMARK_NR_FILES_PER_ITERATION	\
		--nr-top-directories $FSMARK_NR_TOP_DIRECTORIES		\
		--nr-sub-directories $FSMARK_NR_SUB_DIRECTORIES		\
		--sync-mode $FSMARK_SYNCMODE				\
		--iterations $FSMARK_ITERATIONS
	return $?
}
