
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-vmscale \
		--cases "$VMSCALE_CASES"
	return $?
}
