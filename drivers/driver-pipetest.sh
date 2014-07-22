FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	BIND_SWITCH=
	if [ "$PIPETEST_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$PIPETEST_BINDING
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-pipetest \
		-i $PIPETEST_ITERATIONS $BIND_SWITCH
	return $?
}
