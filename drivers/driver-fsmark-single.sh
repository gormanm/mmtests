$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh fsmark

run_bench() {
	FSMARK_NR_TOP_DIRECTORIES=${FSMARK_NR_TOP_DIRECTORIES:-1}
	$SHELLPACK_INCLUDE/shellpack-bench-fsmark			\
		--min-threads 1						\
		--max-threads 1						\
		--filesize $FSMARK_FILESIZE				\
		--nr-files-per-iteration $FSMARK_NR_FILES_PER_ITERATION	\
		--nr-top-directories $FSMARK_NR_TOP_DIRECTORIES		\
		--nr-sub-directories $FSMARK_NR_SUB_DIRECTORIES		\
		--iterations $FSMARK_ITERATIONS
	return $?
}
