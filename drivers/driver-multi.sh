$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netperf
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh kernbench
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh tbench4

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-multi
	return $?
}
