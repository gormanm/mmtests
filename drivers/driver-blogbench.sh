NAMEEXTRA=

run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-blogbench \
		--iterations $BLOGBENCH_ITERATIONS

	return $?
}
