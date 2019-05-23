$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh speccpu2017

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-speccpu2017 $SPECCPU_BUILDONLY	\
		--input-data-size $SPECCPU_DATA_SIZE				\
		--iterations	  $SPECCPU_ITERATIONS				\
		--tests		  $SPECCPU_TESTS				\
		--parallel        $SPECCPU_PARALLEL
	RETVAL=$?
	return $RETVAL
}
