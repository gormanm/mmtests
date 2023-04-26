
run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-thpchallenge 	\
		--min-threads $THPCHALLENGE_MIN_THREADS		\
		--max-threads $THPCHALLENGE_MAX_THREADS		\
		--fio-threads $THPCHALLENGE_FIO_THREADS		\
		--thp-size    $THPCHALLENGE_THP_WSETSIZE	\
		--fio-size    $THPCHALLENGE_FIO_WSETSIZE
	return $?
}
