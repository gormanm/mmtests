
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-kvmstart 	\
		--nr-cpus	$KVMSTART_NR_CPUS		\
		--min-memory	$KVMSTART_MIN_MEMORY		\
		--max-memory	$KVMSTART_MAX_MEMORY		\
		--iterations	$KVMSTART_ITERATIONS
	return $?
}
