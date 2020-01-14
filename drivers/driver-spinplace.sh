run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-spinplace \
		--duration $SPINPLACE_DURATION
	return $?
}
