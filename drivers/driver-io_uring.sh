
run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-io_uring \
		${IOURING_TEST_TYPE:+--type "${IOURING_TEST_TYPE}"}		\
		${IOURING_THREADS:+--threads "${IOURING_THREADS}"}		\
		${IOURING_RUNTIME:+--runtime "${IOURING_RUNTIME}"}		\
		${IOURING_CMD_EXTRA:+--extra-args "${IOURING_CMD_EXTRA}"}

	return $?
}
