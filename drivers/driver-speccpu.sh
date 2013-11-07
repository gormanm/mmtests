FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	for PAGESIZE in $SPECCPU_PAGESIZES; do
		unset USELARGE
		unset USE_DYNAMIC_HUGEPAGES
		unset MMTESTS_HUGECTL
		case $PAGESIZE in
		base)
			disable_transhuge
			;;
		huge-heap)
			hugeadm --hard --pool-pages-min DEFAULT:4096MB
			hugeadm --pool-pages-max DEFAULT:8192
			export MMTESTS_HUGECTL="hugectl --verbose 0 --heap"
			disable_transhuge
			;;
		huge-all)
			hugeadm --hard --pool-pages-min DEFAULT:4096MB
			hugeadm --pool-pages-max DEFAULT:8192
			export MMTESTS_HUGECTL="hugectl --verbose 0 --text --data --bss --heap"
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
		$SCRIPTDIR/shellpacks/shellpack-bench-speccpu \
			--input-data-size $SPECCPU_DATA_SIZE \
			--iterations	  $SPECCPU_ITERATIONS \
			--pagesize        $PAGESIZE \
			--tests		  $SPECCPU_TESTS
		RETVAL=$?
	done

	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL
	return $RETVAL
}
