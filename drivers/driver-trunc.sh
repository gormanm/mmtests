run_bench() {
	VERSION_PARAM=

	$SHELLPACK_INCLUDE/shellpack-bench-trunc 	\
		--iterations	$TRUNC_ITERATIONS	\
		--nr-files	$TRUNC_NR_FILES		\
		--filesize	$TRUNC_FILESIZE
	return $?
}
