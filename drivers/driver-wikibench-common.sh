$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh wikibench

run_bench() {
	VERSION_PARAM=

	if [ "$WIKIBENCH_VERSION" != "" ]; then
		VERSION_PARAM="-v $WIKIBENCH_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-wikibench $VERSION_PARAM	\
		--warmup-time  $WIKIBENCH_WARMUP			\
		--min-workers  $WIKIBENCH_MIN_WORKERS			\
		--max-workers  $WIKIBENCH_MAX_WORKERS			\
		--sut-hostname $WIKIBENCH_SUT_HOSTNAME			\
		--sut-port     $WIKIBENCH_SUT_PORT			\
		--size         $WIKIBENCH_SIZE				\
		--sampling     $WIKIBENCH_SAMPLING
	return $?
}
