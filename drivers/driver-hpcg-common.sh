$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh hpcg

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-hpcg \
		--parallelise-type	$HPCG_PARALLELISE_TYPE \
		--duration		$HPCG_DURATION \
		--iterations		$HPCG_ITERATIONS
	return $?
}
