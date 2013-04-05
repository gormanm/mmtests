FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-compress \
		--method	$COMPRESS_METHOD \
		--source	$COMPRESS_SOURCE \
		--sourcesize	$COMPRESS_APPROXIMATE_SIZE_MB \
		--instances	$COMPRESS_INSTANCES
	return $?
}
