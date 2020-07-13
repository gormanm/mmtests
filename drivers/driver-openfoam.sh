
run_bench() {
	VERSION_PARAM=
	if [ "$OPENFOAM_VERSION" != "" ]; then
		VERSION_PARAM="-v $OPENFOAM_VERSION"
	fi
	BIND_SWITCH=
	if [ "$OPENFOAM_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$OPENFOAM_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-openfoam $VERSION_PARAM $BIND_SWITCH
	return $?
}
