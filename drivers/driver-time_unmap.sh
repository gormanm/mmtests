run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-time_unmap \
		--threads $TIME_UNMAP_THREADS	\
		--size $TIME_UNMAP_SIZE		\
		--iterations $TIME_UNMAP_ITERATIONS
	return $?
}
