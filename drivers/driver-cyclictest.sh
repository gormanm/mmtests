$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh cyclictest

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-cyclictest				\
		${CYCLICTEST_AFFINITY_ALL:+--affinity-all}			\
		${CYCLICTEST_BACKGROUND:+--background $CYCLICTEST_BACKGROUND}	\
		${CYCLICTEST_PRIORITY:+--priority $CYCLICTEST_PRIORITY}		\
		${CYCLICTEST_DISTANCE:+--distance $CYCLICTEST_DISTANCE}		\
		${CYCLICTEST_DURATION:+--duration $CYCLICTEST_DURATION}		\
		${CYCLICTEST_FINEGRAINED:+--fine-grained}
	return $?
}
