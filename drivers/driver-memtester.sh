FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-memtester \
		--instances $MEMTESTER_INSTANCES \
		--mb-usage  $MEMTESTER_MEMORY_MB
	return $?
}
