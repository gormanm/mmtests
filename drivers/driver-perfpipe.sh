NAMEEXTRA=

run_bench() {
	VERSION_PARAM=
	if [ "$PERFPIPE_VERSION" != "" ]; then
		VERSION_PARAM="-v $PERFPIPE_VERSION"
	fi
	BIND_SWITCH=
	if [ "$PERFPIPE_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$PERFPIPE_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-perfpipe $VERSION_PARAM $BIND_SWITCH	\
		--loops		$PERFPIPE_LOOPS					\
		--iterations	$PERFPIPE_ITERATIONS
	return $?
}
