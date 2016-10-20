FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-graphdb \
		--read-threads		$GRAPHDB_READ_THREADS	\
		--write-threads		$GRAPHDB_WRITE_THREADS	\
		--file-size		$GRAPHDB_FILESIZE	\
		--workingset-size	$GRAPHDB_WORKINGSET	\
		--duration		$GRAPHDB_DURATION
	return $?
}
