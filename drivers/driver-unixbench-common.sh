FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	VERSION_PARAM=
	if [ "$UNIXBENCH_WORKLOADS" = "" ]; then
		UNIXBENCH_WORKLOADS=execl
		$SHELLPACK_INCLUDE/shellpack-bench-unixbench $VERSION_PARAM
		return $?
	fi
	if [ "$UNIXBENCH_VERSION" != "" ]; then
		VERSION_PARAM="-v $UNIXBENCH_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-unixbench $VERSION_PARAM	\
		--min-threads $UNIXBENCH_MIN_THREADS			\
		--max-threads $UNIXBENCH_MAX_THREADS			\
		--workloads $UNIXBENCH_WORKLOADS

	return $?
}
