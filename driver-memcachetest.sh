FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-memcachetest \
		--threads $MEMCACHETEST_CONCURRENCY \
		--duration $MEMCACHETEST_DURATION \
		--value-size $MEMCACHETEST_VALUE_SIZE \
		--memcached-mempool $MEMCACHED_MEMPOOL
}
