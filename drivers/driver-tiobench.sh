NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-tiobench
	return $?
}
