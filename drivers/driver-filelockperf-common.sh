$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh filelockperf

run_bench() {
	VERSION_PARAM=
	if [ "$FILELOCKPERF_WORKLOADS" = "" ]; then
		FILELOCKPERF_WORKLOADS="flock01,flock02,posix01,posix02,lease01,lease02"
		$SHELLPACK_INCLUDE/shellpack-bench-filelockperf $VERSION_PARAM
		return $?
	fi
	if [ "$FILELOCKPERF_VERSION" != "" ]; then
		VERSION_PARAM="-v $FILELOCKPERF_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-filelockperf $VERSION_PARAM	\
		--min-threads $FILELOCKPERF_MIN_THREADS			\
		--max-threads $FILELOCKPERF_MAX_THREADS			\
		--workloads $FILELOCKPERF_WORKLOADS

	return $?
}
