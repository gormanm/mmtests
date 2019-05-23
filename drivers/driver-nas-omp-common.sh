$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh nas-omp

run_bench() {
	if [ "$NAS_MAX_CPUS" = "" ]; then
		NAS_MAX_CPUS=$NUMCPUS
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-nas	\
		--type OMP				\
		--max-cpus $NAS_MAX_CPUS		\
		--iterations $NAS_ITERATIONS		\
		--joblist $NAS_JOBLIST
	return $?
}
