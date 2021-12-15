# Create profiling hooks
PROFILE_TITLE="timer"
export PROFILE_EVENTS=timer

PERF_RECORD_COMMAND="record -a"
PERF_REPORT_COMMAND="report"
ARCHIVE_MINIMUM=yes

cat << EOF > monitor-pre-hook
#!/bin/bash

perf $PERF_RECORD_COMMAND -o \$1/perf-\$2-${PROFILE_TITLE}.data &
echo \$! > /tmp/mmtests.perf.pid
EOF

cat << EOF > monitor-post-hook
#!/bin/bash

ARCHIVE_ONE=$ARCHIVE_MINIMUM
WAITPID=\`cat /tmp/mmtests.perf.pid\`
kill \$WAITPID
sleep 1
echo Waiting on perf pid \$WAITPID to exit: \`date\`
while [ "\`ps h --pid \$WAITPID\`" != "" ]; do
	echo -n .
	sleep 1
done
echo Perf exited: \`date\`

# Note, this saves space but if there are multiple tests (e.g. many clients)
# then it assumes that the same binaries are used for each test.
if [ "\$ARCHIVE_ONE" = "yes" ]; then
	if [ ! -e \$1/perf-symbol-archive.data.tar.bz2 ]; then
		echo Creating perf archive
		perf archive \$1/perf-\$2-${PROFILE_TITLE}.data
		mv \$1/perf-\$2-${PROFILE_TITLE}.data.tar.bz2 \$1/perf-symbol-archive.data.tar.bz2
	else
		echo Archive perf-symbol-archive.data.tar.bz2 already exists, use ARCHIVE_MINIMUM=no to override
	fi
else
	echo Creating perf archive
	perf archive \$1/perf-\$2-${PROFILE_TITLE}.data
fi

echo Creating perf report
perf $PERF_REPORT_COMMAND -i \$1/perf-\$2-${PROFILE_TITLE}.data > \$1/perf-\$2-${PROFILE_TITLE}.txt
gzip \$1/perf-\$2-${PROFILE_TITLE}.data
exit 0
EOF

echo "#!/bin/bash" > monitor-cleanup-hook

chmod u+x monitor-*
