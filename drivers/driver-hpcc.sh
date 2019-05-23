
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-hpcc \
		--workload-size $HPCC_WORKLOAD_SIZE \
		--iterations    $HPCC_ITERATIONS
	return $?
}
