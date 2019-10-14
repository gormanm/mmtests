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
		--protocol   $IPERF3_PROTOCOL		\
		--msg-size   $IPERF3_MESSAGE_SIZE	\
		--msg-rate   $IPERF3_MESSAGE_RATE	\
		--min-client $IPERF3_MIN_CLIENTS	\
		--max-client $IPERF3_MAX_CLIENTS	\
		--duration   $IPERF3_DURATION
	return $?
}
