
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-specjbb \
		--starting-warehouses  $SPECJBB_STARTING_WAREHOUSES \
		--increment-warehouses $SPECJBB_INCREMENT_WAREHOUSES \
		--ending-warehouses    $SPECJBB_ENDING_WAREHOUSES \
		--instances            $SPECJBB_JVM_INSTANCES
	return $?
}
