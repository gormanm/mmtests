FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-fsmark \
		--threads 1 \
		--filesize $FSMARK_FILESIZE \
		--nr-files-per-iteration $FSMARK_NR_FILES_PER_ITERATION \
		--nr-files-per-directory $FSMARK_NR_FILES_PER_DIRECTORY \
		--nr-directories $FSMARK_NR_DIRECTORIES \
		--iterations $FSMARK_ITERATIONS
}
