NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-pyarray \
		-i $PYARRAY_ITERATIONS
	return $?
}
