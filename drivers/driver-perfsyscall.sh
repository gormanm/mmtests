
run_bench() {
	VERSION_PARAM=
	if [ "$PERFSYSCALL_VERSION" != "" ]; then
		VERSION_PARAM="-v $PERFSYSCALL_VERSION"
	fi
	BIND_SWITCH=
	if [ "$PERFSYSCALL_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$PERFSYSCALL_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-perfsyscall $VERSION_PARAM $BIND_SWITCH	\
		--loops		$PERFSYSCALL_LOOPS					\
		--iterations	$PERFSYSCALL_ITERATIONS
	return $?
}
