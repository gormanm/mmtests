
run_bench() {
	VERSION_PARAM=
	if [ "$WIS_WORKLOADS" = "" ]; then
		WIS_WORKLOADS=wis-futex
		$SHELLPACK_INCLUDE/shellpack-bench-wis $VERSION_PARAM
		return $?
	fi
	if [ "$WIS_VERSION" != "" ]; then
		VERSION_PARAM="-v $WIS_VERSION"
	fi


	$SHELLPACK_INCLUDE/shellpack-bench-wis $VERSION_PARAM \
	    --min-threads $WIS_MIN_THREADS			\
	    --max-threads $WIS_MAX_THREADS			\
	    --iterations $WIS_ITERATIONS			\
	    --models $WIS_MODELS			\
	    --workloads $WIS_WORKLOADS

	return $?
}
