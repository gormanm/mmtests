SERVER_SIDE_SUPPORT=yes

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-monitor
	return $?
}
