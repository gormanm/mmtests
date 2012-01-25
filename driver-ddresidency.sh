FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	if [ "$DD_RESIDENCY_MAX_DURATION" != "" ]; then
		$SCRIPTDIR/shellpacks/shellpack-bench-ddresidency	\
			--mapping-size $DD_RESIDENCY_MAPPING_SIZE	\
			--filesize $DD_RESIDENCY_FILESIZE		\
			--max-duration $DD_RESIDENCY_MAX_DURATION
	else
		$SCRIPTDIR/shellpacks/shellpack-bench-ddresidency	\
			--mapping-size $DD_RESIDENCY_MAPPING_SIZE	\
			--filesize $DD_RESIDENCY_FILESIZE
	fi
}
