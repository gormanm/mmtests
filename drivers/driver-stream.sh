FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

if [ "$STREAM_METHOD" = "single" ]; then
	STREAM_THREADS=1
fi

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-stream \
		--workload-size $STREAM_SIZE	\
		--nr-threads	$STREAM_THREADS \
		--method	$STREAM_METHOD	\
		--iterations	$STREAM_ITERATIONS
	return $?
}
