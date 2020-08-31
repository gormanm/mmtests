run_bench() {
	VERSION_PARAM=
	if [ "$MPAS_VERSION" != "" ]; then
		VERSION_PARAM="-v $MPAS_VERSION"
	fi
	BIND_SWITCH=
	if [ "$MPAS_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$MPAS_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-mpas $VERSION_PARAM $BIND_SWITCH	\
		--processes $MPAS_PROCESSES					\
		--threads   $MPAS_THREADS					\
		--model $MPAS_MODEL
	return $?
}
