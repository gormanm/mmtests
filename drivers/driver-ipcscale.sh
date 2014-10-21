FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-ipcscale	\
		--iterations	$IPCSCALE_ITERATIONS
	return $?
}
