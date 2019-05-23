NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-specjbb2015 \
		--instances            $SPECJBB_JVM_INSTANCES
	return $?
}
