FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	eval $SHELLPACK_INCLUDE/shellpack-bench-swappiness \
		--size        		$SWAPPINESS_WORKLOAD_SIZE \
		--anon-size		$SWAPPINESS_ANON_PERCENTAGE \
		--min-swappiness	$SWAPPINESS_MIN_SWAPPINESS \
		--max-swappiness	$SWAPPINESS_MAX_SWAPPINESS \
		--steps			$SWAPPINESS_STEPS

	return $?
}
