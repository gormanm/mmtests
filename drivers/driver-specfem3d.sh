
run_bench() {
	VERSION_PARAM=
	if [ "$SPECFEM3D_VERSION" != "" ]; then
		VERSION_PARAM="-v $SPECFEM3D_VERSION"
	fi
	BIND_SWITCH=
	if [ "$SPECFEM3D_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$SPECFEM3D_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-specfem3d $VERSION_PARAM $BIND_SWITCH
	return $?
}
