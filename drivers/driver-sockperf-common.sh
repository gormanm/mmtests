SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-sockperf

run_bench() {
	BIND_SWITCH=
	if [ "$SOCKPERF_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$SOCKPERF_BINDING
	fi
	if [ "$SOCKPERF_SERVER" != "" ]; then
		SERVER_ADDRESS="--server-address $SOCKPERF_SERVER"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-sockperf $BIND_SWITCH \
		$SERVER_ADDRESS				\
		--protocol  $SOCKPERF_PROTOCOL		\
		--duration  $SOCKPERF_DURATION		\
		--msg-sizes $SOCKPERF_MESSAGE_SIZES	\
		--msg-rates $SOCKPERF_MESSAGE_RATES	\
		--test-type $SOCKPERF_TESTTYPE
	return $?
}
