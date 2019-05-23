NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-sysjitter \
		--duration $SYSJITTER_DURATION	     \
		--threshold $SYSJITTER_THRESHOLD
	return $?
}
