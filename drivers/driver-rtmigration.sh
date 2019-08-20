run_bench() {
	RTMIGRATION_CHECK_SWITCH=
	if [ "$RTMIGRATION_CHECK" = "yes" ]; then
		RTMIGRATION_CHECK_SWITCH="--check"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-rtmigration $RTMIGRATION_CHECK_SWITCH \
		--duration   $RTMIGRATION_DURATION
	return $?
}
