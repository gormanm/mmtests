FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-nas	\
		--type OMP				\
		--max-cpus $NAS_MAX_CPUS
	return $?
}
