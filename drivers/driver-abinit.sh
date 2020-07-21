
run_bench() {
	VERSION_PARAM=
	if [ "$ABINIT_VERSION" != "" ]; then
		VERSION_PARAM="-v $ABINIT_VERSION"
	fi
	BIND_SWITCH=
	if [ "$ABINIT_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$ABINIT_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-abinit $VERSION_PARAM $BIND_SWITCH \
		--max-cpus $ABINIT_MAXCPUS	\
		--model $ABINIT_MODEL
	return $?
}
