NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-thpfioscale 	\
		--min-threads $THPFIOSCALE_MIN_THREADS	\
		--max-threads $THPFIOSCALE_MAX_THREADS	\
		--fio-threads $THPFIOSCALE_FIO_THREADS	\
		--thp-size    $THPFIOSCALE_THP_SIZE	\
		--fio-size    $THPFIOSCALE_FIO_SIZE
	return $?
}
