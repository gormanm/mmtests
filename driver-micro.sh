FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-micro \
		--tests $MICRO_TESTLIST
}
