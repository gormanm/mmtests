
run_bench() {
	GROUP_PARAM=
	if [ "$TRINITY_GROUP" != "" ]; then
		GROUP_PARAM="--group $TRINITY_GROUP"
	fi

	SYSCALL_PARAM=
	if [ "$TRINITY_SYSCALL" != "" ]; then
		SYSCALL_PARAM="--syscall $TRINITY_SYSCALL"
	fi

	VERSION_PARAM=
	if [ "$TRINITY_VERSION" != "" ]; then
		VERSION_PARAM="-v $TRINITY_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-trinity $SYSCALL_PARAM $GROUP_PARAM $VERSION_PARAM \
		--duration $TRINITY_DURATION
	return $?
}
