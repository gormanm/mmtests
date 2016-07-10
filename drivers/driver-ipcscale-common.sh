FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	VERSION_PARAM=
	if [ "$IPCSCALE_WORKLOADS" = "" ]; then
		IPCSCALE_WORKLOADS=waitforzero
		$SHELLPACK_INCLUDE/shellpack-bench-ipcscale $VERSION_PARAM
		return $?
	fi
	if [ "$IPCSCALE_VERSION" != "" ]; then
		VERSION_PARAM="-v $IPCSCALE_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-ipcscale $VERSION_PARAM	\
		--min-threads $IPCSCALE_MIN_THREADS			\
		--max-threads $IPCSCALE_MAX_THREADS			\
		--complexops  $IPCSCALE_COMPLEXOPS			\
		--iterations  $IPCSCALE_ITERATIONS			\
		--workloads   $IPCSCALE_WORKLOADS

	return $?
}
