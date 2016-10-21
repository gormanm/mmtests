FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	DBT2_ITERATIONS_COMMAND=
	DBT2_SCALE_COMMAND=

	if [ "$DBT2_ITERATIONS" != "" ]; then
		DBT2_ITERATIONS_COMMAND="--iterations $DBT2_ITERATIONS"
	fi

	eval $SHELLPACK_INCLUDE/shellpack-bench-dbt2 \
		$DBT2_EXTRA_COMMAND				\
		$DBT2_ITERATIONS_COMMAND $DBT2_SCALE_COMMAND	\
		--dbdriver $DBT2_DRIVER				\
		--shared-buffers $OLTP_SHAREDBUFFERS		\
		--effective-cachesize $OLTP_CACHESIZE		\
		--scale-factor $DBT2_SCALE_FACTOR		\
		--duration $DBT2_DURATION			\
		--min-users $DBT2_MIN_USERS			\
		--max-users $DBT2_MAX_USERS
}
