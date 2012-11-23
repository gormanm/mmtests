if [ "$SAMPLE_CYCLE_FACTOR" = "" ]; then
	SAMPLE_CYCLE_FACTOR=1
fi

CALLGRAPH=
if [ "$OPROFILE_REPORT_CALLGRAPH" != "" ]; then
	CALLGRAPH=$OPROFILE_REPORT_CALLGRAPH
	CALLGRAPH_SWITCH=--callgraph
	if [ $SAMPLE_CYCLE_FACTOR -lt 15 ]; then
		SAMPLE_CYCLE_FACTOR=15
	fi
fi

# Create profiling hooks
PROFILE_TITLE="timer"

echo "#!/bin/bash" > monitor-pre-hook
case `uname -m` in
	i?86)
		echo "oprofile_start.sh $CALLGRAPH_SWITCH $CALLGRAPH --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer" >> monitor-pre-hook
		export PROFILE_EVENTS=timer
		;;
	x86_64)
		echo "oprofile_start.sh $CALLGRAPH_SWITCH $CALLGRAPH --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer" >> monitor-pre-hook
		export PROFILE_EVENTS=timer
		;;
	ppc64)
		echo "oprofile_start.sh $CALLGRAPH_SWITCH $CALLGRAPH --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer" >> monitor-pre-hook
		export PROFILE_EVENTS=timer
		;;
	*)
		echo Unrecognised architecture
		exit -1
		;;
esac

echo "#!/bin/bash" > monitor-post-hook
echo "opcontrol --dump" >> monitor-post-hook
echo "opcontrol --stop" >> monitor-post-hook
echo "oprofile_report.sh > \$1/oprofile-\$2-report-$PROFILE_TITLE.txt" >> monitor-post-hook

echo "#!/bin/bash" > monitor-cleanup-hook
echo "rm \$1/oprofile-\$2-report-$PROFILE_TITLE.txt" >> monitor-cleanup-hook

echo "#!/bin/bash" > monitor-reset
echo "opcontrol --stop   > /dev/null 2> /dev/null" >> monitor-reset
echo "opcontrol --deinit > /dev/null 2> /dev/null" >> monitor-reset

chmod u+x monitor-*
