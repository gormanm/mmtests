FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-ltp \
		--ltp-tests $LTP_RUN_TESTS
	return $?
}
