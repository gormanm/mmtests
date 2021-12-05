$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh pmqtest

run_bench() {
	if [ "$PMQTEST_PINNED" = "yes" ]; then
		PMQTEST_PINNED_PARAM="--affinity"
	fi
	PMQTEST_BACKGROUND_PARAM=
	if [ "$PMQTEST_BACKGROUND" != "" ]; then
		PMQTEST_BACKGROUND_PARAM="--background $PMQTEST_BACKGROUND"
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-pmqtest $PMQTEST_PINNED_PARAM $PMQTEST_BACKGROUND_PARAM \
		--duration $PMQTEST_DURATION --pairs $PMQTEST_PAIRS
	return $?
}
