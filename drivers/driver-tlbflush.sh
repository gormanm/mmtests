FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-tlbflush \
		--max-threads $TLBFLUSH_MAX_THREADS \
		--max-entries $TLBFLUSH_MAX_ENTRIES \
		--iterations $TLBFLUSH_ITERATIONS
	return $?
}
