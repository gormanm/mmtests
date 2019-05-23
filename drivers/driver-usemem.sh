
run_bench() {
	USEMEM_FAKE_SWAP_MB_SWITCH=
	if [ "$USEMEM_FAKE_SWAP_MB" != "" ]; then
		USEMEM_FAKE_SWAP_MB_SWITCH="--fake-swap \"$USEMEM_FAKE_SWAP_MB\""
	fi

	eval $SHELLPACK_INCLUDE/shellpack-bench-usemem $USEMEM_FAKE_SWAP_MB_SWITCH \
		--size        		$USEMEM_WORKLOAD_SIZE	\
		--anon-percentage	$USEMEM_PERCENTAGE_ANON \
		--loops			$USEMEM_LOOPS		\
		--iterations		$USEMEM_ITERATIONS	\
		--min-threads		$USEMEM_MIN_THREADS	\
		--max-threads		$USEMEM_MAX_THREADS

	return $?
}
