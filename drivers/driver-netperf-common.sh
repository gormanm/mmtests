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
	$SCRIPTDIR/shellpacks/shellpack-bench-netperf $BIND_SWITCH \
		--protocols $NETPERF_PROTOCOLS \
		--buffer-sizes $NETPERF_BUFFER_SIZES
	return $?
}
