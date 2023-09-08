# Create profiling hooks
PROFILE_TITLE=cycles
PERF_RECORD_COMMAND="record -a"
PERF_REPORT_COMMAND=
ARCHIVE_MINIMUM=yes

cat << EOF > monitor-pre-hook
#!/bin/bash

perf $PERF_RECORD_COMMAND -o \$1/perf-\$2-${PROFILE_TITLE}.data &
echo \$! > /tmp/mmtests.perf.pid
EOF

cat << EOF > monitor-post-hook
#!/bin/bash

WAITPID=\`cat /tmp/mmtests.perf.pid\`
kill -2 \$WAITPID
sleep 1
echo Waiting on perf pid \$WAITPID to exit: \`date\`
while [ "\`ps h --pid \$WAITPID\`" != "" ]; do
	echo -n .
	sleep 1
done
echo Perf exited: \`date\`

ARCHIVE_ONE=$ARCHIVE_MINIMUM
PROFILE_NAME=perf-\$2-${PROFILE_TITLE}
perf report --stdio --header-only -i \$1/\$PROFILE_NAME.data | grep -q 'contains stat data'
IS_STAT=\$?
perf report --stdio --header-only -i \$1/\$PROFILE_NAME.data | grep -q 'sample_type = .*CALLCHAIN'
IS_CALLGRAPH=\$?

if [ \$IS_STAT -ne 0 ]; then
	# Note, this saves space but if there are multiple tests (e.g. many clients)
	# then it assumes that the same binaries are used for each test.
	if [ "\$ARCHIVE_ONE" = "yes" ]; then
		if [ ! -e \$1/perf-symbol-archive.data.tar.bz2 ]; then
			echo Creating perf archive
			perf archive \$1/\$PROFILE_NAME.data
			mv \$1/\$PROFILE_NAME.data.tar.bz2 \$1/perf-symbol-archive.data.tar.bz2
		else
			echo Archive perf-symbol-archive.data.tar.bz2 already exists, use ARCHIVE_MINIMUM=no to override
		fi
	else
		echo Creating perf archive
		perf archive \$1/\$PROFILE_NAME.data
	fi
fi

echo Creating perf report
if [ -n "$PERF_REPORT_COMMAND" ]; then
	perf $PERF_REPORT_COMMAND -i \$1/\$PROFILE_NAME.data > \$1/\$PROFILE_NAME.txt
elif [ \$IS_STAT -eq 0 ]; then
	perf stat report \\
		-i \$1/\$PROFILE_NAME.data &> \$1/\$PROFILE_NAME.txt
	perf stat report -A \\
		-i \$1/\$PROFILE_NAME.data &>> \$1/\$PROFILE_NAME.txt
elif [ \$IS_CALLGRAPH -eq 0 ]; then
	perf report --stdio -F overhead,sample,period,comm,dso,sym -g none \\
		-i \$1/\$PROFILE_NAME.data > \$1/\$PROFILE_NAME.txt
	perf report --stdio --header -F overhead,sample,period,comm,dso -g none \\
		-i \$1/\$PROFILE_NAME.data > \$1/\${PROFILE_NAME}-dso.txt
	perf report --stdio -s sample,period,comm,dso,sym -g graph,0.01 \\
		-i \$1/\$PROFILE_NAME.data > \$1/\${PROFILE_NAME}-cg.txt
	perf report --stdio -s sample,period,comm -g graph,0.01 \\
		-i \$1/\$PROFILE_NAME.data > \$1/\${PROFILE_NAME}-cg-comm.txt
	perf report --stdio -s sample,period,comm,dso,sym -g graph,0.05 --no-children \\
		-i \$1/\$PROFILE_NAME.data > \$1/\${PROFILE_NAME}-no-children.txt
else
	perf report --stdio -s sample,period,comm,dso,sym \\
		-i \$1/\$PROFILE_NAME.data > \$1/\$PROFILE_NAME.txt
	perf report --stdio -s sample,period,comm,dso,sym,cpu \\
		-i \$1/\$PROFILE_NAME.data > \$1/\${PROFILE_NAME}-cpu.txt
	perf report --header --stdio -s sample,period,comm,dso \\
		-i \$1/\$PROFILE_NAME.data > \$1/\${PROFILE_NAME}-dso.txt
fi

gzip \$1/\$PROFILE_NAME.data \$1/\${PROFILE_NAME}*.txt
exit 0
EOF

echo "#!/bin/bash" > monitor-cleanup-hook

chmod u+x monitor-*
