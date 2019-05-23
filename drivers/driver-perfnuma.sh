NAMEEXTRA=

run_bench() {
	VERSION_PARAM=
	if [ "$PERFNUMA_VERSION" != "" ]; then
		VERSION_PARAM="-v $PERFNUMA_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-perfnuma $VERSION_PARAM	\
		--nr-processes $PERFNUMA_NR_PROCESSES			\
		--nr-threads   $PERFNUMA_NR_THREADS			\
		--process-wss  $PERFNUMA_PROCESS_WSS			\
		--workloads    "$PERFNUMA_WORKLOADS"			\
		--iterations   $PERFNUMA_ITERATIONS
	return $?
}
