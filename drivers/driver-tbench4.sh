FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	if [ "$TBENCH_SERVER" != "" ]; then
		SERVER_ADDRESS="--server-address $TBENCH_SERVER"
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-tbench 	\
		$SERVER_ADDRESS				\
		-v 4.0 					\
		--max-clients $TBENCH_MAX_CLIENTS
	return $?
}
