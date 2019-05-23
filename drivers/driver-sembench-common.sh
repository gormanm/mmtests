$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh sembench

run_bench() {
	VERSION_PARAM=
	if [ "$SEMBENCH_WORKLOADS" = "" ]; then
		SEMBENCH_WORKLOADS=sem
		$SHELLPACK_INCLUDE/shellpack-bench-sembench $VERSION_PARAM
		return $?
	fi
	if [ "$SEMBENCH_VERSION" != "" ]; then
		VERSION_PARAM="-v $SEMBENCH_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-sembench $VERSION_PARAM	\
		--min-threads $SEMBENCH_MIN_THREADS			\
		--max-threads $SEMBENCH_MAX_THREADS			\
		--workloads $SEMBENCH_WORKLOADS

	return $?
}
