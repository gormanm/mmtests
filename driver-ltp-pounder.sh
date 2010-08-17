FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-ltp-pounder \
		--ltp-runtime $LTP_POUNDER_RUNTIME
}
