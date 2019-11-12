$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh memcachetest

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-memcachetest \
		--threads $MEMCACHETEST_CONCURRENCY \
		--duration $MEMCACHETEST_DURATION \
		--value-size $MEMCACHETEST_VALUE_SIZE \
		--memcached-mempool $MEMCACHED_MEMPOOL
	return $?
}
