
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-hpagealloc 	\
		--pagesize	$HPAGEALLOC_PAGESIZE	\
		--nr		$HPAGEALLOC_NR		\
		--stride	$HPAGEALLOC_STRIDE
	return $?
}
