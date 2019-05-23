NAMEEXTRA=

run_bench() {
	VERSION_PARAM=

	$SHELLPACK_INCLUDE/shellpack-bench-mediawikibuild --init
	return $?
}
