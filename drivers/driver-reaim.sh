FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-reaim \
		--filesize $REAIM_FILESIZE \
		--poolsize $REAIM_POOLSIZE \
		--startusers $REAIM_STARTUSERS \
		--endusers $REAIM_ENDUSERS \
		--increment $REAIM_INCREMENT \
		--jobs-per-user $REAIM_JOBS_PER_USER \
		--workfile $REAIM_WORKFILE \
		--iterations $REAIM_ITERATIONS
	return $?
}
