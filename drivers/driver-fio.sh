
run_bench() {
	# If no filesystem was mounted and there is not a custom fixed file, do
	# IO on the TEST_PARTITION itself (block device).
	if [ "${FIO_TARGET_FILE}" = "" -a "${TESTDISK_NOMOUNT}" = "true" ]; then
		FIO_TARGET_FILE=${TESTDISK_PARTITION}
	fi

	$SCRIPTDIR/shellpacks/shellpack-bench-fio \
		${FIO_TARGET_FILE:+--target_file "$FIO_TARGET_FILE"} \
		${FIO_CMD_OPTIONS:+--cmdline "$FIO_CMD_OPTIONS"}
	return $?
}
