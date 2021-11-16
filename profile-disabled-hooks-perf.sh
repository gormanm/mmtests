# Create profiling hooks
PROFILE_TITLE="timer"
export PROFILE_EVENTS=timer

PERF_RECORD_COMMAND="record -a"
PERF_REPORT_COMMAND="report"

cat << EOF > monitor-pre-hook
#!/bin/bash

perf $PERF_RECORD_COMMAND -o \$1/perf-\$2-${PROFILE_TITLE}.data &
echo \$! > /tmp/mmtests.perf.pid
EOF

cat << EOF > monitor-post-hook
#!/bin/bash

WAITPID=\`cat /tmp/mmtests.perf.pid\`
kill \$WAITPID
sleep 1
echo Waiting on perf pid \$WAITPID to exit: \`date\`
while [ "\`ps h --pid \$WAITPID\`" != "" ]; do
	echo -n .
	sleep 1
done
echo Perf exited: \`date\`

echo Creating perf archive
perf archive \$1/perf-\$2-${PROFILE_TITLE}.data
echo Creating perf report
perf $PERF_REPORT_COMMAND -i \$1/perf-\$2-${PROFILE_TITLE}.data > \$1/perf-\$2-${PROFILE_TITLE}.txt
gzip \$1/perf-\$2-${PROFILE_TITLE}.data
exit 0
EOF

echo "#!/bin/bash" > monitor-cleanup-hook

chmod u+x monitor-*
