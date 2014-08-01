FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	PGBENCH_MAX_TIME_COMMAND=
	PGBENCH_MAX_TRANSACTIONS_COMMAND=
	PGBENCH_ITERATIONS_COMMAND=
	PGBENCH_SCALE_COMMAND=

	if [ "$PGBENCH_MAX_TIME" != "" ]; then
		PGBENCH_MAX_TIME_COMMAND="--max-time $PGBENCH_MAX_TIME"
		PGBENCH_MAX_TRANSACTIONS_COMMAND=
	fi
	if [ "$PGBENCH_MAX_TRANSACTIONS" != "" ]; then
		PGBENCH_MAX_TIME_COMMAND=
		PGBENCH_MAX_TRANSACTIONS_COMMAND="--max-transactions $PGBENCH_MAX_TRANSACTIONS"
	fi
	if [ "$PGBENCH_ITERATIONS" != "" ]; then
		PGBENCH_ITERATIONS_COMMAND="--iterations $PGBENCH_ITERATIONS"
	fi
	if [ "$PGBENCH_SCALE_FACTOR" != "" ]; then
		PGBENCH_SCALE_COMMAND="--scale-factor $PGBENCH_SCALE_FACTOR"
	fi
	if [ "$PGBENCH_READONLY" = "yes" ]; then
		PGBENCH_READONLY=--read-only
	else
		PGBENCH_READONLY=
	fi

	LOGDIR_TOPLEVEL=$LOGDIR_RESULTS
	for PAGESIZE in $OLTP_PAGESIZES; do
		unset USELARGE
		unset USE_DYNAMIC_HUGEPAGES
		case $PAGESIZE in
		base)
			unset USELARGE
			unset USE_DYNAMIC_HUGEPAGES
			disable_transhuge
			;;
		huge)
			USELARGE=--use-large-pages
			unset USE_DYNAMIC_HUGEPAGES
			disable_transhuge
			;;
		dynhuge)
			USELARGE=--use-large-pages
			export USE_DYNAMIC_HUGEPAGES=yes
			disable_transhuge
			;;
		transhuge)
			unset USELARGE
			unset USE_DYNAMIC_HUGEPAGES
			if [ "$TRANSHUGE_AVAILABLE" = "yes" ]; then
				enable_transhuge
			else
				echo THP support unavailable for transhuge
				continue
			fi
			;;
		default)
			unset USELARGE
			unset USE_DYNAMIC_HUGEPAGES
			reset_transhuge
			;;
		esac

		export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/$PAGESIZE
		mkdir -p $LOGDIR_RESULTS
		$SHELLPACK_INCLUDE/shellpack-bench-pgbench $USELARGE $PGBENCH_READONLY \
			$PGBENCH_MAX_TIME_COMMAND $PGBENCH_MAX_TRANSACTIONS_COMMAND \
			$PGBENCH_ITERATIONS_COMMAND $PGBENCH_SCALE_COMMAND \
			--shared-buffers $OLTP_SHAREDBUFFERS \
			--max-threads $PGBENCH_MAX_THREADS \
			--effective-cachesize $OLTP_CACHESIZE
		RETVAL=$?
	done
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL
	unset USELARGE
	unset USE_DYNAMIC_HUGEPAGES
	return $RETVAL
}
