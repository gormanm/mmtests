$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh tbench
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh dbench
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-tbench
SERVER_SIDE_SUPPORT=yes

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-tbench 	\
		$SERVER_ADDRESS				\
		--min-clients $TBENCH_MIN_CLIENTS	\
		--max-clients $TBENCH_MAX_CLIENTS
	return $?
}
