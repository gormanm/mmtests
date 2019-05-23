NAMEEXTRA=

run_bench() {
	LOGDIR_TOPLEVEL=$LOGDIR_RESULTS
	for PAGESIZE in $PFT_PAGESIZES; do
		unset USELARGE
		unset USE_DYNAMIC_HUGEPAGES
		case $PAGESIZE in
		base)
			disable_transhuge
			;;
		transhuge)
			if [ "$TRANSHUGE_AVAILABLE" = "yes" ]; then
				enable_transhuge
			else
				echo THP support unavailable for transhuge
				continue
			fi
			;;
		default)
			reset_transhuge
			;;
		esac

		export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/$PAGESIZE
		mkdir -p $LOGDIR_RESULTS
		$SHELLPACK_INCLUDE/shellpack-bench-pft
		RETVAL=$?
	done
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL
	return $RETVAL
}
