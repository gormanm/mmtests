FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	BIND_SWITCH=
	if [ "$NETPERF_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$NETPERF_BINDING
	fi
	if [ "$NETPERF_PROTOCOLS" = "" ]; then
		NETPERF_PROTOCOLS=UDP_STREAM
	fi
	if [ "$NETPERF_SERVER" != "" ]; then
		SERVER_ADDRESS="--server-address $NETPERF_SERVER"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-netperf $BIND_SWITCH \
		$SERVER_ADDRESS \
		--iterations $NETPERF_ITERATIONS \
		--protocols $NETPERF_PROTOCOLS \
		--buffer-sizes $NETPERF_BUFFER_SIZES
	return $?
}
