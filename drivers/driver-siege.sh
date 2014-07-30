FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	SIEGE_ITER_COMMAND=
	if [ "$SIEGE_ITER_TIME" != "" ]; then
		SIEGE_ITER_COMMAND="--time-per-iter $SIEGE_ITER_TIME"
	fi
	if [ "$SIEGE_ITER_REPS" != "" ]; then
		SIEGE_ITER_COMMAND="--reps-per-iter $SIEGE_ITER_REPS"
	fi

	eval $SHELLPACK_INCLUDE/shellpack-bench-siege $SIEGE_ITER_COMMAND \
		--max-users $SIEGE_MAX_USERS \
		--iterations $SIEGE_ITERATIONS

	return $?
}
