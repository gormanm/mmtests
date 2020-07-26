$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netcdfcbuild
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netcdffcbuild

run_bench() {
	VERSION_PARAM=
	if [ "$WRF_VERSION" != "" ]; then
		VERSION_PARAM="-v $WRF_VERSION"
	fi
	BIND_SWITCH=
	if [ "$WRF_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$WRF_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-wrf $VERSION_PARAM $BIND_SWITCH	\
		--max-cpus $WRF_MAXCPUS						\
		--model $WRF_MODEL
	return $?
}
