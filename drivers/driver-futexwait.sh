
run_bench() {
	VERSION_PARAM=
	if [ "$FUTEXWAIT_VERSION" != "" ]; then
		VERSION_PARAM="-v $FUTEXWAIT_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-futexwait $VERSION_PARAM	\
		--min-threads $FUTEXWAIT_MIN_THREADS			\
		--max-threads $FUTEXWAIT_MAX_THREADS			\
		--iterations $FUTEXWAIT_ITERATIONS

	return $?
}
