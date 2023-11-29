$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netperf
SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-netperf

run_bench() {
	$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netperf
	$SCRIPTDIR/shellpacks/shellpack-bench-netperf 					\
		${NETPERF_VERSION:+-v "${NETPERF_VERSION}"}				\
		${NETPERF_BINDING:+--bind-"${NETPERF_BINDING}"}				\
		${NETPERF_SERVER:+--server-address "${NETPERF_SERVER}"}			\
		${NETPERF_ITERATIONS:+--iterations "${NETPERF_ITERATIONS}"}		\
		${NETPERF_NR_PAIRS:+--nr-pairs "${NETPERF_NR_PAIRS}"}			\
		${NETPERF_NET_PROTOCOL:+--net-protocol "${NETPERF_NET_PROTOCOL}"}	\
		${NETPERF_PROTOCOL:+--protocol "${NETPERF_PROTOCOL}"}			\
		${NETPERF_BUFFER_SIZES:+--buffer-sizes "${NETPERF_BUFFER_SIZES}"}
	return $?
}
