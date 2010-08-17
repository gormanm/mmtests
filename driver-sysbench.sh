FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
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
		esac

		export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/$PAGESIZE
		mkdir -p $LOGDIR_RESULTS
		$SHELLPACK_INCLUDE/shellpack-bench-sysbench $USELARGE \
			--oltp-testtype $OLTP_TESTTYPE $OLTP_READONLY $OLTP_SIZE $OLTP_CONFIDENCE $OLTP_MAX_THREADS \
			--shared_buffers $OLTP_SHAREDBUFFERS \
			--effective_cachesize $OLTP_CACHESIZE \
			--use-postgres
	done
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL
	unset USELARGE
	unset USE_DYNAMIC_HUGEPAGES
}
