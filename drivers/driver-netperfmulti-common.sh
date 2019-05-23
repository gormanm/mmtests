SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-netperfmulti
NAMEEXTRA=

run_bench() {
	BIND_SWITCH=
	if [ "$NETPERFMULTI_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$NETPERFMULTI_BINDING
	fi
	if [ "$NETPERFMULTI_PROTOCOL" = "" ]; then
		NETPERFMULTI_PROTOCOL=UDP_STREAM
	fi
	if [ "$NETPERFMULTI_SERVER" != "" ]; then
		SERVER_ADDRESS="--server-address $NETPERFMULTI_SERVER"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-netperfmulti $BIND_SWITCH \
		$SERVER_ADDRESS \
		--iterations  $NETPERFMULTI_ITERATIONS \
		--duration    $NETPERFMULTI_DURATION   \
		--min-threads $NETPERFMULTI_MIN_THREADS \
		--max-threads $NETPERFMULTI_MAX_THREADS \
		--protocol    $NETPERFMULTI_PROTOCOL \
		--buffer-size $NETPERFMULTI_BUFFER_SIZE
	return $?
}
