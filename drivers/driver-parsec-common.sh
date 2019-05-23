$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh parsec

run_bench() {
	if [ "$PARSEC_WORKLOAD" = "" ]; then
		PARSEC_WORKLOAD="blackscholes"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-parsec	\
		--parallel $PARSEC_PARALLEL		\
		--size $PARSEC_SIZE			\
		--iterations $PARSEC_ITERATIONS		\
		--workload $PARSEC_WORKLOAD		\
		--threads $PARSEC_THREADS

	return $?
}
