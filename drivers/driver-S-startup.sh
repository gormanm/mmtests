FINEGRAIN_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-S-startup \
		--iterations $S_STARTUP_REPETITIONS
	return $?
}
