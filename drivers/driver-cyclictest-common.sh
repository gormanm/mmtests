FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	if [ "$CYCLICTEST_PINNED" = "yes" ]; then
		CYCLICTEST_PINNED_PARAM="--affinity"
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-cyclictest $CYCLICTEST_PINNED_PARAM \
		--iterations $CYCLICTEST_ITERATIONS    \
		--duration   $CYCLICTEST_DURATION
	return $?
}
