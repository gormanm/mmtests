FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-stressng \
		--min-threads $STRESSNG_MIN_THREADS	\
		--max-threads $STRESSNG_MAX_THREADS	\
		--runtime     $STRESSNG_RUNTIME		\
		--iterations  $STRESSNG_ITERATIONS	\
		--testname    $STRESSNG_TESTNAME
	return $?
}
