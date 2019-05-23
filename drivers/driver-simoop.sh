
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-simoop			\
		--warm-time		$SIMOOP_WARMTIME_DURATION	\
		--run-time		$SIMOOP_RUNTIME_DURATION	\
		--threads		$SIMOOP_THREADS			\
		--working-set-thread	$SIMOOP_WORKINGSET_THREAD_MB	\
		--burn-threads		$SIMOOP_BURN_THREADS		\
		--rw-threads		$SIMOOP_READWRITE_THREADS	\
		--du-threads		$SIMOOP_DU_THREADS		\
		--nr-directories	$SIMOOP_FILE_DIRECTORIES	\
		--nr-files		$SIMOOP_NUMFILES		\
		--filesize		$SIMOOP_FILESIZE_MB		\
		--read-size		$SIMOOP_READSIZE_MB		\
		--write-size		$SIMOOP_WRITESIZE_MB		\
		--report-frequency	$SIMOOP_REPORT_FREQUENCY
	return $?
}
