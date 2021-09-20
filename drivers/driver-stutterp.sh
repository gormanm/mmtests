
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-stutterp \
		--size $STUTTER_SIZE				\
		--file-percentage $STUTTER_FILE_PERCENTAGE	\
		--memfault-tmpfs $STUTTER_MEMFAULT_TMPFS	\
		--duration $STUTTER_DURATION			\
		--min-threads $STUTTER_MIN_THREADS		\
		--max-threads $STUTTER_MAX_THREADS
	return $?
}
