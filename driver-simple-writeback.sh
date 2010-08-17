FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	if [ "$SIMPLE_WRITEBACK_CONV" != "" ]; then
		$SHELLPACK_INCLUDE/shellpack-bench-simple-writeback \
			--min-cpu-factor $SIMPLE_WRITEBACK_MIN_CPU_FACTOR \
			--max-cpu-factor $SIMPLE_WRITEBACK_MAX_CPU_FACTOR \
			--filesize $SIMPLE_WRITEBACK_FILESIZE \
			--bs $SIMPLE_WRITEBACK_BS \
			--conv $SIMPLE_WRITEBACK_CONV
	else
		$SHELLPACK_INCLUDE/shellpack-bench-simple-writeback \
			--min-cpu-factor $SIMPLE_WRITEBACK_MIN_CPU_FACTOR \
			--max-cpu-factor $SIMPLE_WRITEBACK_MAX_CPU_FACTOR \
			--filesize $SIMPLE_WRITEBACK_FILESIZE \
			--bs $SIMPLE_WRITEBACK_BS
	fi
}
