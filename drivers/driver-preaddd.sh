FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-preaddd \
		--min-instances $PREADDD_MIN_INSTANCES \
		--targetsize $PREADDD_TARGETSIZE_MB \
		--iterations $PREADDD_ITERATIONS \
	return $?
}
