FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	if [ "$TIMEDALLOC_FILL_SIZE" = "" ]; then
		TIMEDALLOC_FILL_SIZE=0
	fi

	$SCRIPTDIR/shellpacks/shellpack-bench-timedalloc	\
		--fill-size $TIMEDALLOC_FILL_SIZE		\
		--alloc-size $TIMEDALLOC_ALLOC_SIZE

	return $?
}
