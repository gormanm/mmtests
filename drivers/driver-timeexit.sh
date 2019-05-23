
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-timeexit \
		-d $TIMEEXIT_DELAY \
		-c $TIMEEXIT_INSTANCES \
		-i $TIMEEXIT_ITERATIONS
	return $?
}
