FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	taskset -c 0 $SCRIPTDIR/shellpacks/shellpack-bench-vmr-cacheeffects
	return $?
}
