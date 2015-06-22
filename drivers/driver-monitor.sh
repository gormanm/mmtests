FINEGRAINED_SUPPORTED=no
SERVER_SIDE_SUPPORT=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-monitor
	return $?
}
