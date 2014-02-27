FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	if [ "$ARRAYSMASH_ARRAYSIZE" != "" ]; then
		$SHELLPACK_INCLUDE/shellpack-bench-arraysmash	\
			--language   $ARRAYSMASH_LANGUAGE	\
			--arraysize  $ARRAYSMASH_ARRAYSIZE	\
			--iterations $ARRAYSMASH_ITERATIONS
	else
		$SHELLPACK_INCLUDE/shellpack-bench-arraysmash	\
			--language   $ARRAYSMASH_LANGUAGE	\
			--arraymem   $ARRAYSMASH_ARRAYMEM	\
			--iterations $ARRAYSMASH_ITERATIONS
	fi
	return $?
}
