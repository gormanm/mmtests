$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh dbench

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-dbench -v 65b19870
	return $?
}
