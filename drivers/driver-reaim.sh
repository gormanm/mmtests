NAMEEXTRA=

run_bench() {
	if [ "$REAIM_EXCLUDE" = "" ]; then
		REAIM_EXCLUDE=none
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-reaim \
		--filesize      $REAIM_FILESIZE \
		--poolsize      $REAIM_POOLSIZE \
		--startusers    $REAIM_STARTUSERS \
		--endusers      $REAIM_ENDUSERS \
		--increment     $REAIM_INCREMENT \
		--workfiles     "$REAIM_WORKFILES" \
		--exclude       $REAIM_EXCLUDE \
		--iterations    $REAIM_ITERATIONS
	return $?
}
