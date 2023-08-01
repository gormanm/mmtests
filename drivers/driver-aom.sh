run_bench() {
	ENCODER_SWITCH=
	if [ "$AOM_ENCODER_SPEED" != "" ]; then
		ENCODER_SWITCH="--encoder-speed $AOM_ENCODER_SPEED"
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-aom $ENCODER_SWITCH \
		--min-threads	$AOM_MIN_THREADS	\
		--max-threads	$AOM_MAX_THREADS	\
		--source-file	$AOM_SOURCE_FILE
	return $?
}
