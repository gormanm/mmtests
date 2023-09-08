$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh iperf3
SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-iperf3

run_bench() {
	BIND_SWITCH=
	if [ "$IPERF3_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$IPERF3_BINDING
	fi
	if [ "$IPERF3_SERVER" != "" ]; then
		SERVER_ADDRESS="--server-address $IPERF3_SERVER"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-iperf3 $BIND_SWITCH \
		$SERVER_ADDRESS				\
		--net-protocol	$IPERF3_NET_PROTOCOL	\
		--protocol	$IPERF3_PROTOCOL	\
		--buffer-sizes	$IPERF3_BUFFER_SIZES	\
		--bitrates	$IPERF3_BITRATES	\
		--min-streams	$IPERF3_MIN_STREAMS	\
		--max-streams	$IPERF3_MAX_STREAMS	\
		--duration	$IPERF3_DURATION	\
		--iterations	$IPERF3_ITERATIONS
	return $?
}
