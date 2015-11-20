FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-sqlite	\
		--size		$SQLITE_SIZE
	return $?
}
