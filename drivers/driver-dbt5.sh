FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	DBT5_SCALE_COMMAND=

	echo $SHELLPACK_INCLUDE/shellpack-bench-dbt5 \
		$DBT5_EXTRA_COMMAND \
		$DBT5_SCALE_COMMAND \
		--dbdriver $DBT5_DRIVER \
		--shared-buffers $OLTP_SHAREDBUFFERS \
		--nr-customers $DBT5_NR_CUSTOMERS \
		--nr-trade-days $DBT5_NR_TRADE_DAYS \
		--scale-factor $DBT5_SCALE_FACTOR \
		--effective-cachesize $OLTP_CACHESIZE \
		--duration $DBT5_DURATION \
		--user-scale $DBT5_USER_SCALE \
		--pacing-delay $DBT5_PACING_DELAY \
		--min-users $DBT5_MIN_USERS \
		--max-users $DBT5_MAX_USERS

	eval $SHELLPACK_INCLUDE/shellpack-bench-dbt5 \
		$DBT5_EXTRA_COMMAND $DBT5_SCALE_COMMAND \
		--dbdriver $DBT5_DRIVER \
		--shared-buffers $OLTP_SHAREDBUFFERS \
		--nr-customers $DBT5_NR_CUSTOMERS \
		--nr-trade-days $DBT5_NR_TRADE_DAYS \
		--scale-factor $DBT5_SCALE_FACTOR \
		--effective-cachesize $OLTP_CACHESIZE \
		--duration $DBT5_DURATION \
		--user-scale $DBT5_USER_SCALE \
		--pacing-delay $DBT5_PACING_DELAY \
		--min-users $DBT5_MIN_USERS \
		--max-users $DBT5_MAX_USERS
}
