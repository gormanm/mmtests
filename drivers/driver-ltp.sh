
run_bench() {
	LTP_RUN_ARGS_SWITCH=
	if [ "$LTP_RUN_ARGS" != "" ]; then
		LTP_RUN_ARGS_SWITCH="--ltp-args \"$LTP_RUN_ARGS\""
	fi

	eval $SCRIPTDIR/shellpacks/shellpack-bench-ltp \
			--ltp-tests "$LTP_RUN_TESTS" $LTP_RUN_ARGS_SWITCH
	return $?
}
