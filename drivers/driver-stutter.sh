FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-stutter	\
		--memfault-size $STUTTER_MEMFAULT_SIZE	\
		--filesize $STUTTER_FILESIZE		\
		--blocksize $STUTTER_BLOCKSIZE
	return $?
}
