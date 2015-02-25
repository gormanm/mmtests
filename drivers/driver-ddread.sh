FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-ddread \
		--targetsize $DDREAD_TARGETSIZE_MB \
		--iterations $DDREAD_ITERATIONS
	return $?
}
