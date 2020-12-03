# Create profiling hooks
PROFILE_TITLE="timer"
export PROFILE_EVENTS=timer

PERF_RECORD_COMMAND="record -a"
PERF_REPORT_COMMAND="report"

echo "#!/bin/bash" > monitor-pre-hook
echo "
perf $PERF_RECORD_COMMAND  -o \$1/perf-\$2-report-${PROFILE_TITLE}.data &
echo \$! > /tmp/mmtests.perf.pid
" >> monitor-pre-hook

echo "#!/bin/bash" > monitor-post-hook
echo 'WAITPID=`cat /tmp/mmtests.perf.pid`' >> monitor-post-hook
echo 'kill $WAITPID' >> monitor-post-hook
echo 'sleep 1' >> monitor-post-hook
echo 'echo Waiting on perf pid $WAITPID to exit: `date`' >> monitor-post-hook
echo 'while [ "`ps h --pid $WAITPID`" != "" ]; do' >> monitor-post-hook
echo 'echo -n .' >> monitor-post-hook
echo 'sleep 1' >> monitor-post-hook
echo 'done' >> monitor-post-hook
echo 'echo Perf exited: `date`' >> monitor-post-hook
echo 'echo Creating perf archive' >> monitor-post-hook
echo "perf archive \$1/perf-\$2-report-${PROFILE_TITLE}.data" >> monitor-post-hook
echo 'echo Creating perf report' >> monitor-post-hook
echo "perf $PERF_REPORT_COMMAND -i \$1/perf-\$2-report-${PROFILE_TITLE}.data > \$1/perf-\$2-report-${PROFILE_TITLE}.txt" >> monitor-post-hook
echo "gzip \$1/perf-\$2-report-${PROFILE_TITLE}.data" >> monitor-post-hook
echo "exit 0" >> monitor-post-hook

echo "#!/bin/bash" > monitor-cleanup-hook

chmod u+x monitor-*
