
run_bench() {
	LOCAL_PARAM=
	if [ "$STUTTER_USE_LOCAL" = "yes" ]; then
		LOCAL_PARAM=--source-local
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-stutter $LOCAL_PARAM \
		--memfault-size $STUTTER_MEMFAULT_SIZE		\
		--memfault-tmpfs $STUTTER_MEMFAULT_TMPFS	\
		--filesize $STUTTER_FILESIZE			\
		--blocksize $STUTTER_BLOCKSIZE
	return $?
}
