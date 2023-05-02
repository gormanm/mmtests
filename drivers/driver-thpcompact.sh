
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-thpcompact 	\
		--min-threads	$THPCOMPACT_MIN_THREADS	\
		--max-threads	$THPCOMPACT_MAX_THREADS	\
		--anon-mapsize	$THPCOMPACT_ANONSIZE	\
		--file-mapsize	$THPCOMPACT_FILESIZE
	return $?
}
