run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-nap \
		${NAP_DURATION:+--duration "${NAP_DURATION}"}		\
		${NAP_MSG_INTERVAL:+--interval "${NAP_MSG_INTERVAL}"}

	return $?
}
