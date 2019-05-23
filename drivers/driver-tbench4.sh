SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-tbench
SERVER_SIDE_SUPPORT=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-tbench 	\
		$SERVER_ADDRESS				\
		-v 4.0 					\
		--max-clients $TBENCH_MAX_CLIENTS
	return $?
}
