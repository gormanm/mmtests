
run_bench() {
	VERSION_PARAM=
	if [ "$PERFFUTEXWAKE_VERSION" != "" ]; then
		VERSION_PARAM="-v $PERFFUTEXWAKE_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-perffutexwake $VERSION_PARAM	\
		--iterations	$PERFFUTEXWAKE_ITERATIONS		\
		--nr-wake	$PERFFUTEXWAKE_NR_WAKE			\
		--min-threads	$PERFFUTEXWAKE_MIN_THREADS		\
		--max-threads	$PERFFUTEXWAKE_MAX_THREADS
	return $?
}
