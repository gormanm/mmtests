
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-pgioperf $PGIOPERF_INIT_SWITCH \
		--data-size              $PGIOPERF_DATA_SIZE \
		--wal-size               $PGIOPERF_WAL_SIZE \
		--random-readers         $PGIOPERF_NUM_RANDOM_READERS \
		--read-report-interval   $PGIOPERF_READ_REPORT_INTERVAL \
		--wal-report-interval    $PGIOPERF_WAL_REPORT_INTERVAL  \
		--commit-report-interval $PGIOPERF_COMMIT_REPORT_INTERVAL \
		--samples                $PGIOPERF_SAMPLES
	return $?
}
