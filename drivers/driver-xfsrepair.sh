NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-xfsrepair	\
		--threads $XFSREPAIR_THREADS		\
		--iterations $XFSREPAIR_ITERATIONS
	return $?
}
