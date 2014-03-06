FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	if [ "$BONNIE_FSYNC" = "yes" ]; then
		BONNIE_FSYNC_PARAM="--sync"
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-bonnie $BONNIE_FSYNC_PARAM \
		--dataset  $BONNIE_DATASET_SIZE \
		--nr_files $BONNIE_NR_FILES \
		--nr_directories $BONNIE_NR_DIRECTORIES \
		--iterations $BONNIE_ITERATIONS
	return $?
}
