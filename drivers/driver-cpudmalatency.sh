FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-cpudmalatency	\
		--duration	$CPUDMALATENCY_DURATION		\
		--quiet		$CPUDMALATENCY_QUIET		\
		--latency	$CPUDMALATENCY_LATENCY
	return $?
}
