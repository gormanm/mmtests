FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	CMAOPT=
	if [ "$NAS_USE_CMA" = "yes" ]; then 
		CMAOPT="--cma"
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-nas --type MPI $CMAOPT
	return $?
}
