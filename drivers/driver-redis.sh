SERVER_SIDE_SUPPORT=yes
SERVER_SIDE_BENCH_SCRIPT=shellpacks/shellpack-bench-redis

run_bench() {
	BIND_SWITCH=
	SERVER_ADDRESS=
	if [ "$REDIS_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$REDIS_BINDING
	fi
	if [ "$REDIS_SERVER" != "" ]; then
		SERVER_ADDRESS="--server-address $REDIS_SERVER"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-redis $BIND_SWITCH \
		$SERVER_ADDRESS \
		--iterations  $REDIS_ITERATIONS \
		--min-clients $REDIS_MIN_CLIENTS \
		--max-clients $REDIS_MAX_CLIENTS \
		--requests    $REDIS_REQUESTS \
		--keyspace    $REDIS_KEYSPACE
	return $?
}
