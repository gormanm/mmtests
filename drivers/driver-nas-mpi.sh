FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	CMAOPT=
	if [ "$NAS_USE_CMA" = "yes" ]; then 
		CMAOPT="--cma"
	fi
	if [ "$NAS_MAX_CPUS" = "" ]; then
		NAS_MAX_CPUS=$((NUMCPUS*3/4))
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-nas $CMAOPT	\
		--type MPI $CMAOPT				\
		--max-cpus $NAS_MAX_CPUS
	return $?
}
