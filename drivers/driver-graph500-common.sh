NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-graph500 \
		--workset		$GRAPH500_WORKSET	\
		--parallelize		$GRAPH500_PARALLELIZE
	return $?
}
