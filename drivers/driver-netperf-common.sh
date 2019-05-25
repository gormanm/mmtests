$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netperf
SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-netperf

run_bench() {
	BIND_SWITCH=
	if [ "$NETPERF_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$NETPERF_BINDING
	fi
	if [ "$NETPERF_PROTOCOL" = "" ]; then
		NETPERF_PROTOCOL=UDP_STREAM
	fi
	if [ "$NETPERF_SERVER" != "" ]; then
		SERVER_ADDRESS="--server-address $NETPERF_SERVER"
	fi
	$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netperf
	$SCRIPTDIR/shellpacks/shellpack-bench-netperf $BIND_SWITCH \
		$SERVER_ADDRESS \
		--iterations $NETPERF_ITERATIONS \
		--protocol $NETPERF_PROTOCOL \
		--buffer-sizes $NETPERF_BUFFER_SIZES
	return $?
}
