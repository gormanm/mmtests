FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-fsmark \
		--min-threads $FSMARK_MIN_THREADS \
		--max-threads $FSMARK_MAX_THREADS \
		--filesize $FSMARK_FILESIZE \
		--nr-files-per-iteration $FSMARK_NR_FILES_PER_ITERATION \
		--nr-sub-directories $FSMARK_NR_SUB_DIRECTORIES \
		--iterations $FSMARK_ITERATIONS
	return $?
}
