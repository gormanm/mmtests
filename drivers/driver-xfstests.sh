NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-xfstests
	return $?
}
