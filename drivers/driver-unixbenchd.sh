$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh unixbench

run_bench() {
	VERSION_PARAM=
	if [ "$UNIXBENCHD_VERSION" != "" ]; then
		VERSION_PARAM="-v $UNIXBENCHD_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-unixbenchd $VERSION_PARAM	\
		--iterations  $UNIXBENCHD_ITERATIONS			\
		--duration    $UNIXBENCHD_DURATION			\
		--subcommand  $UNIXBENCHD_SUBCOMMAND			\
		--subparam    $UNIXBENCHD_SUBPARAM

	return $?
}
