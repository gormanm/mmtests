NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-pistress \
		--min-invgroups $PISTRESS_MIN_INVGROUPS \
		--max-invgroups $PISTRESS_MAX_INVGROUPS \
		--runtime $PISTRESS_RUNTIME
	return $?
}
