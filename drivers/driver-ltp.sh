FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	LTP_RUN_ARGS_SWITCH=
	if [ "$LTP_RUN_ARGS" != "" ]; then
		LTP_RUN_ARGS_SWITCH="--ltp-args \"$LTP_RUN_ARGS\""
	fi
	LTP_RUN_ITERATIONS_SWITCH=
	if [ "$LTP_RUN_ITERATIONS" != "" ]; then
		LTP_RUN_ITERATIONS_SWITCH="--ltp-iterations \"$LTP_RUN_ITERATIONS\""
	fi

	eval $SCRIPTDIR/shellpacks/shellpack-bench-ltp \
			--ltp-tests "$LTP_RUN_TESTS" $LTP_RUN_ARGS_SWITCH $LTP_RUN_ITERATIONS_SWITCH
	return $?
}
