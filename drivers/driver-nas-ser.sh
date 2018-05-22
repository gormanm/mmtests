FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-nas --type SER --iterations $NAS_ITERATIONS
	return $?
}
