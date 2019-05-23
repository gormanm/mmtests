NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-dbench -v 4.1alpha
	return $?
}
