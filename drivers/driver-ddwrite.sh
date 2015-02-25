FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-ddwrite \
		--targetsize $DDWRITE_TARGETSIZE_MB \
		--iterations $DDWRITE_ITERATIONS
	return $?
}
