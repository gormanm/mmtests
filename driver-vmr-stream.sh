FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	LOGDIR_TOPLEVEL=$LOGDIR_RESULTS
	for PAGESIZE in $STREAM_PAGESIZES; do
		case $PAGESIZE in
		base)
			PAGEPARAM=--smallonly
			unset USE_DYNAMIC_HUGEPAGES
			disable_transhuge
			;;
		huge)
			PAGEPARAM=--hugeonly
			unset USE_DYNAMIC_HUGEPAGES
			disable_transhuge
			;;
		dynhuge)
			PAGEPARAM=--hugeonly
			export USE_DYNAMIC_HUGEPAGES=yes
			disable_transhuge
			;;
		transhuge)
			PAGEPARAM=--smallonly
			unset USE_DYNAMIC_HUGEPAGES
			if [ "$TRANSHUGE_AVAILABLE" = "yes" ]; then
				enable_transhuge
			else
				echo THP support unavailable for transhuge
				continue
			fi
			;;
		default)
			PAGEPARAM=--smallonly
			unset USE_DYNAMIC_HUGEPAGES
			reset_transhuge
			;;
		esac

		export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/$PAGESIZE
		$SCRIPTDIR/shellpacks/shellpack-bench-vmr-stream \
			$PAGEPARAM \
			--backing $STREAM_BACKING_TYPE
		RETVAL=$?
	done
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL
	unset PAGEPARAM
	unset USE_DYNAMIC_HUGEPAGES
	return $RETVAL
}
