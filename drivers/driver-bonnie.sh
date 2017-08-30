FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	if [ "$BONNIE_FSYNC" = "yes" ]; then
		BONNIE_FSYNC_PARAM="--sync"
	fi
	if [ "$BONNIE_NR_FILES" != "" ]; then
		FILES_PARAM="--nr_files $BONNIE_NR_FILES --dirsize $BONNIE_DIRECTORY_SIZE"
	fi
	if [ "$BONNIE_NR_DIRECTORIES" != "" ]; then
		DIRS_PARAM="--nr_directories $BONNIE_NR_DIRECTORIES"
	fi
	if [ "$BONNIE_DATASET_SIZE" != "" ]; then
		SIZE_PARAM="--dataset $BONNIE_DATASET_SIZE"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-bonnie $BONNIE_FSYNC_PARAM \
		$SIZE_PARAM \
		$FILES_PARAM \
		$DIRS_PARAM \
		--iterations $BONNIE_ITERATIONS
	return $?
}
