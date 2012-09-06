FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-pipetest \
		-i $PIPETEST_ITERATIONS
	return $?
}
