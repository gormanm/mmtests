FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-tbench 	\
		-v 4.0 					\
		--max-clients $TBENCH_MAX_CLIENTS
	return $?
}
