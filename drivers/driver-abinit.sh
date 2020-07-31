
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
		--processes $ABINIT_PROCESSES	\
		--threads   $ABINIT_THREADS	\
		--model $ABINIT_MODEL
	return $?
}
