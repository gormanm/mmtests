NAMEEXTRA=

run_bench() {
	USEPERF_PARAM=
	if [ "$VMSCALE_USE_PERF" = "yes" ]; then
		USEPERF_PARAM=--use-perf
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-vmscale $USEPERF_PARAM \
		--cases "$VMSCALE_CASES"
	return $?
}
