$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh dbench

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-dbench
	return $?
}
