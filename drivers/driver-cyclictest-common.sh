FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	if [ "$CYCLICTEST_PINNED" = "yes" ]; then
		CYCLICTEST_PINNED_PARAM="--affinity"
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-cyclictest \
		--runtime $CYCLICTEST_RUNTIME $CYCLICTEST_PINNED_PARAM
	return $?
}
