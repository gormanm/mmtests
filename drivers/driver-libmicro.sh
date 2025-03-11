$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh libmicro

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-libmicro
	return $?
}
