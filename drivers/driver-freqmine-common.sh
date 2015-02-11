FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	VERSION_PARAM=
	if [ "$FREQMINE_SIZE" = "" ]; then
		FREQMINE_SIZE=small
		$SHELLPACK_INCLUDE/shellpack-bench-freqmine $VERSION_PARAM
		return $?
	fi
	if [ "$FREQMINE_VERSION" != "" ]; then
		VERSION_PARAM="-v $FREQMINE_VERSION"
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-freqmine $VERSION_PARAM	\
		--min-threads $FREQMINE_MIN_THREADS			\
		--max-threads $FREQMINE_MAX_THREADS			\
		--iterations  $FREQMINE_ITERATIONS			\
		--size $FREQMINE_SIZE

	return $?
}
