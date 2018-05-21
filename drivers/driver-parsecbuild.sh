FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-parsecbuild	\
		--parallel	$PARSEC_PARALLEL		\
		--size		$PARSEC_SIZE
	return $?
}
