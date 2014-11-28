FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-fsmark \
		--min-threads $FSMARK_MIN_THREADS \
		--max-threads $FSMARK_MAX_THREADS \
		--filesize $FSMARK_FILESIZE \
		--nr-files-per-iteration $FSMARK_NR_FILES_PER_ITERATION \
		--nr-files-per-directory $FSMARK_NR_FILES_PER_DIRECTORY \
		--nr-directories $FSMARK_NR_DIRECTORIES \
		--iterations $FSMARK_ITERATIONS
	return $?
}
