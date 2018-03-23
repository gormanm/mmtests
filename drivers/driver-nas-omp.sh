FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	if [ "$NAS_MAX_CPUS" = "" ]; then
		NAS_MAX_CPUS=$NUMCPUS
	fi
	$SCRIPTDIR/shellpacks/shellpack-bench-nas	\
		--type OMP				\
		--max-cpus $NAS_MAX_CPUS
	return $?
}
