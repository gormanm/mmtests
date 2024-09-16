$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh cyclictest

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-cyclictest				\
		${CYCLICTEST_AFFINITY_ALL:+--affinity-all}			\
		${CYCLICTEST_BACKGROUND:+--background $CYCLICTEST_BACKGROUND}	\
		${CYCLICTEST_DISTANCE:+--distance $CYCLICTEST_DISTANCE}		\
		${CYCLICTEST_DURATION:+--duration $CYCLICTEST_DURATION}		\
		${CYCLICTEST_FINEGRAINED:+--fine-grained}			\
		${CYCLICTEST_HISTOGRAM:+--histogram $CYCLICTEST_HISTOGRAM}	\
		${CYCLICTEST_INTERVAL:+--interval $CYCLICTEST_INTERVAL}		\
		${CYCLICTEST_PRIORITY:+--priority $CYCLICTEST_PRIORITY}		\
		${CYCLICTEST_NR_THREADS:+--threads $CYCLICTEST_NR_THREADS}
	return $?
}
