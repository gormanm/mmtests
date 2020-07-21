
run_bench() {
	VERSION_PARAM=
	if [ "$SALMON_VERSION" != "" ]; then
		VERSION_PARAM="-v $SALMON_VERSION"
	fi
	BIND_SWITCH=
	if [ "$SALMON_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$SALMON_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-salmon $VERSION_PARAM $BIND_SWITCH \
		--max-cpus $SALMON_MAXCPUS	\
		--model $SALMON_MODEL		\
		--iterations $SALMON_ITERATIONS
	return $?
}
