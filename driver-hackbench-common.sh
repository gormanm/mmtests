FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-hackbench \
		$IPCMETHOD \
		$HACKBENCH_GROUPS \
		-i 20
}
