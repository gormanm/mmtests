FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-memslap \
		--threads $MEMSLAP_CONCURRENCY \
		--duration $MEMSLAP_DURATION \
		--memcached-mempool $MEMCACHED_MEMPOOL
}
