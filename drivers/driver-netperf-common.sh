$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netperf
SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-netperf

run_bench() {
	if [ "$NETPERF_NR_PAIRS" = "" ]; then
		NETPERF_NR_PAIRS=1
	fi
	BIND_SWITCH=
	VERSION_SWITCH=
	if [ "$NETPERF_VERSION" != "" ]; then
		VERSION_SWITCH="-v $NETPERF_VERSION"
	fi

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
	$SCRIPTDIR/shellpacks/shellpack-bench-netperf $BIND_SWITCH $VERSION_SWITCH \
		$SERVER_ADDRESS \
		--iterations $NETPERF_ITERATIONS	\
		--net-protocol $NETPERF_NET_PROTOCOL	\
		--protocol $NETPERF_PROTOCOL		\
		--buffer-sizes $NETPERF_BUFFER_SIZES	\
		--nr-pairs $NETPERF_NR_PAIRS
	return $?
}
