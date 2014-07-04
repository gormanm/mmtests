FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-specjbb2013 \
		--instances            $SPECJBB_JVM_INSTANCES
	return $?
}
