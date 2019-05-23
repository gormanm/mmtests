
run_bench() {
	CONSUME=
	if [ "$POSTMARK_BACKGROUND_MMAP" = "yes" ]; then
		CONSUME=--consume-memory
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-postmark $CONSUME
	return $?
}
