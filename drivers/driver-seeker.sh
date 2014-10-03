FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	if [ "$SEEKER_TYPE" = "block" ]; then
		$SCRIPTDIR/shellpacks/shellpack-bench-seeker \
			--type block \
			--io   $SEEKER_IO \
			--device $SEEKER_DEVICE
	elif [ "$SEEKER_TYPE" = "file" ]; then
		$SCRIPTDIR/shellpacks/shellpack-bench-seeker \
			--type file \
			--io   $SEEKER_IO
	else
		die Unrecognised SEEKER_TYPE $SEEKER_TYPE
	fi
	return $?
}
