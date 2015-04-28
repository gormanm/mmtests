FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	BIND_SWITCH=
	if [ "$SYSCALL_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$SYSCALL_BINDING
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-syscall \
		$BIND_SWITCH
	return $?
}
