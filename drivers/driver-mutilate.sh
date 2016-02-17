FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-mutilate \
		--min-threads $MUTILATE_MIN_THREADS \
		--max-threads $MUTILATE_MAX_THREADS \
		--iterations $MUTILATE_ITERATIONS \
		--duration $MUTILATE_DURATION \
		--value-size $MUTILATE_VALUE_SIZE \
		--memcached-mempool $MEMCACHED_MEMPOOL
	return $?
}
