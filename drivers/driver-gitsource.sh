FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-gitsource \
		--iterations $GITSOURCE_ITERATIONS

	return $?
}
