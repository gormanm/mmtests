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
		echo "operf_start.sh $CALLGRAPH_SWITCH $CALLGRAPH --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer &" >> monitor-pre-hook
		echo "echo $\! > operf.pid" >> monitor-pre-hook
		export PROFILE_EVENTS=timer
		;;
	x86_64)
		echo "operf_start.sh $CALLGRAPH_SWITCH $CALLGRAPH --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer &" >> monitor-pre-hook
		echo "echo $\! > operf.pid" >> monitor-pre-hook
		export PROFILE_EVENTS=timer
		;;
	ppc64)
		echo "operf_start.sh $CALLGRAPH_SWITCH $CALLGRAPH --sample-cycle-factor $SAMPLE_CYCLE_FACTOR --event timer &" >> monitor-pre-hook
		echo "echo $\! > operf.pid" >> monitor-pre-hook
		export PROFILE_EVENTS=timer
		;;
	*)
		echo Unrecognised architecture
		exit -1
		;;
esac

echo "sleep 5" >> monitor-pre-hook

echo "#!/bin/bash" > monitor-post-hook
echo 'OPERFPID=`cat operf.pid`' >> monitor-post-hook
echo "kill -SIGINT \$OPERFPID" >> monitor-post-hook
echo "while [[ -f operf.pid ]]; do sleep 1; done" >> monitor-post-hook
echo "oprofile_report.sh > \$1/oprofile-\$2-report-$PROFILE_TITLE.txt" >> monitor-post-hook

echo "#!/bin/bash" > monitor-cleanup-hook
echo "rm \$1/oprofile-\$2-report-$PROFILE_TITLE.txt" >> monitor-cleanup-hook

echo "#!/bin/bash" > monitor-reset

chmod u+x monitor-*
