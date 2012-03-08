FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	BIND_SWITCH=
	if [ "$NETPERF_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$NETPERF_BINDING
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-netperf $BIND_SWITCH \
		--$PROTOCOL-only \
		--buffer-sizes $NETPERF_BUFFER_SIZES
}
