NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-xfsio 	\
		--size		$XFSIO_SIZE		\
		--testcases	$XFSIO_TESTCASES	\
		--iterations	$XFSIO_ITERATIONS
	return $?
}
