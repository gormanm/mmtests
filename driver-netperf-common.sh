FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-netperf \
		--$PROTOCOL-only \
		--buffer-sizes $NETPERF_BUFFER_SIZES
}
