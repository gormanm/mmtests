FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-stutter		\
		--memfault-size $STUTTER_MEMFAULT_SIZE		\
		--memfault-tmpfs $STUTTER_MEMFAULT_TMPFS	\
		--filesize $STUTTER_FILESIZE			\
		--blocksize $STUTTER_BLOCKSIZE
	return $?
}
