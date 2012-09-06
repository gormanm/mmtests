FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-vmr-aim9
	return $?
}
