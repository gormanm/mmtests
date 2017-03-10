FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-wptlbflush
	return $?
}
