NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-sparsetruncate	\
		--nr-directories $SPARSETRUNCATE_DIRECTORIES	\
		--nr-files	 $SPARSETRUNCATE_FILES		\
		--filesize	 $SPARSETRUNCATE_FILESIZE
	return $?
}
