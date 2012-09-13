FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-cmattach-test
	return $?
}
