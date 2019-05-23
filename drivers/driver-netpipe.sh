SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-netpipe
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-netpipe
	return $?
}
