FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-rsyncresidency	\
		--source $RSYNC_RESIDENCY_SOURCE 		\
		--destination $RSYNC_RESIDENCY_DESTINATION	\
		--mapping-size $RSYNC_RESIDENCY_MAPPING_SIZE
}
