FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	SYSBENCH_MAX_TIME_COMMAND=
	SYSBENCH_MAX_TRANSACTIONS_COMMAND=
	SYSBENCH_ITERATIONS_COMMAND=
	SYSBENCH_SCALE_COMMAND=

	if [ "$SYSBENCH_MAX_TIME" != "" ]; then
		SYSBENCH_MAX_TIME_COMMAND="--max-time $SYSBENCH_MAX_TIME"
		SYSBENCH_MAX_TRANSACTIONS_COMMAND=
	fi
	if [ "$SYSBENCH_MAX_TRANSACTIONS" != "" ]; then
		SYSBENCH_MAX_TIME_COMMAND=
		SYSBENCH_MAX_TRANSACTIONS_COMMAND="--max-transactions $SYSBENCH_MAX_TRANSACTIONS"
	fi
	if [ "$SYSBENCH_ITERATIONS" != "" ]; then
		SYSBENCH_ITERATIONS_COMMAND="--iterations $SYSBENCH_ITERATIONS"
	fi
	if [ "$SYSBENCH_WORKLOAD_SIZE" != "" ]; then
		SYSBENCH_SCALE_COMMAND="--workload-size $SYSBENCH_WORKLOAD_SIZE"
	fi
	if [ "$SYSBENCH_READONLY" = "yes" ]; then
		SYSBENCH_READONLY=--read-only
	else
		SYSBENCH_READONLY=
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
		eval $SHELLPACK_INCLUDE/shellpack-bench-sysbench $USELARGE $SYSBENCH_READONLY \
			$SYSBENCH_MAX_TIME_COMMAND $SYSBENCH_MAX_TRANSACTIONS_COMMAND \
			$SYSBENCH_ITERATIONS_COMMAND $SYSBENCH_SCALE_COMMAND \
			--dbdriver $SYSBENCH_DRIVER \
			--shared-buffers $OLTP_SHAREDBUFFERS \
			--max-threads $SYSBENCH_MAX_THREADS \
			--effective-cachesize $OLTP_CACHESIZE
		RETVAL=$?
	done
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL
	unset USELARGE
	unset USE_DYNAMIC_HUGEPAGES
	return $RETVAL
}
