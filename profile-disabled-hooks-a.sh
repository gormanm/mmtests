if [ "$SAMPLE_CYCLE_FACTOR" = "" ]; then
	SAMPLE_CYCLE_FACTOR=1
fi

# Create profiling hooks
PROFILE_TITLE="timer"

echo "#!/bin/bash" > monitor-pre-hook
case `uname -m` in
	i?86)
		echo "oprofile_start.sh --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer" >> monitor-pre-hook
		export PROFILE_EVENTS=timer,dtlb_miss
		;;
	x86_64)
		echo "oprofile_start.sh --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer" >> monitor-pre-hook
		export PROFILE_EVENTS=timer,dtlb_miss
		;;
	ppc64)
		echo "oprofile_start.sh --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer" >> monitor-pre-hook
		export PROFILE_EVENTS=timer,dtlb_miss
		;;
	*)
		echo Unrecognised architecture
		exit -1
		;;
esac

echo "#!/bin/bash" > monitor-post-hook
echo "opcontrol --stop" >> monitor-post-hook
echo "oprofile_report.sh > \$1/oprofile-\$2-report-$PROFILE_TITLE.txt" >> monitor-post-hook

echo "#!/bin/bash" > monitor-cleanup-hook
echo "rm \$1/oprofile-\$2-report-$PROFILE_TITLE.txt" >> monitor-cleanup-hook

echo "#!/bin/bash" > monitor-reset
echo "opcontrol --stop   > /dev/null 2> /dev/null" >> monitor-reset
echo "opcontrol --deinit > /dev/null 2> /dev/null" >> monitor-reset

chmod u+x monitor-*
