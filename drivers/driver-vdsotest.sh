run_bench() {
	VERSION_PARAM=
	if [ "$VDSOTEST_VERSION" != "" ]; then
		VERSION_PARAM="-v $VDSOTEST_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-vdsotest $VERSION_PARAM	\
				    --iterations $VDSOTEST_ITERATIONS \
				    --duration   $VDSOTEST_DURATION

	return $?
}
