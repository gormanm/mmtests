SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-redis-memtier

run_bench() {
	SERVER_ADDRESS=
	if [ "$REDIS_MEMTIER_SERVER" != "" ]; then
		SERVER_ADDRESS="--server-address $REDIS_MEMTIER_SERVER"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-redis-memtier		\
		$SERVER_ADDRESS						\
		--iterations      $REDIS_MEMTIER_ITERATIONS		\
		--persistence     $REDIS_MEMTIER_PERSISTENCE		\
		--requests        $REDIS_MEMTIER_REQUESTS		\
		--keyspace-min    $REDIS_MEMTIER_KEYSPACE_MIN		\
		--keyspace-max    $REDIS_MEMTIER_KEYSPACE_MAX		\
		--keyspace-prefix $REDIS_MEMTIER_KEYSPACE_PREFIX	\
		--pipeline        $REDIS_MEMTIER_PIPELINE		\
		--datasize        $REDIS_MEMTIER_DATASIZE		\
		--min-clients     $REDIS_MEMTIER_MIN_CLIENTS		\
		--max-clients     $REDIS_MEMTIER_MAX_CLIENTS
	return $?
}
