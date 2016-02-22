FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-usemem \
		--size        		$USEMEM_WORKLOAD_SIZE	\
		--anon-percentage	$USEMEM_PERCENTAGE_ANON \
		--loops			$USEMEM_LOOPS		\
		--iterations		$USEMEM_ITERATIONS	\
		--min-threads		$USEMEM_MIN_THREADS	\
		--max-threads		$USEMEM_MAX_THREADS

	return $?
}
