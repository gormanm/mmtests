$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh nas

run_bench() {
	CMAOPT=
	if [ "$NAS_USE_CMA" = "yes" ]; then 
		CMAOPT="--cma"
	fi
	if [ "$NAS_MAX_CPUS" = "" ]; then
		NAS_MAX_CPUS=$NUMCPUS
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-nas $CMAOPT	\
		--type $NAS_PARALLEL_TYPE 			\
		--max-cpus $NAS_MAX_CPUS			\
		--iterations $NAS_ITERATIONS			\
		--joblist $NAS_JOBLIST
	return $?
}
