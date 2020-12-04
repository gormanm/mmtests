echo '#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/types.h>
#include <sys/stat.h>

int main() {
	int fd;
	char buf[64];
	int bytes_write, bytes_written;

	fd = open("/tmp/mmtests.wait.pid", O_CREAT|O_TRUNC|O_WRONLY);
	if (fd == -1) {
		perror("open");
		exit(-1);
	}

	snprintf(buf, sizeof(buf), "%d", getpid());
	bytes_written = 0;
	bytes_write = strlen(buf);
	while (bytes_written != bytes_write) {
		bytes_written += write(fd, buf + bytes_written, bytes_write - bytes_written);
	}
	close(fd);
	pause();
	return 0;
}' > /tmp/mmtests-wait.c

# Create profiling hooks
TRACE_EVENTS=
for EVENT in $MONITOR_FTRACE_EVENTS; do
	TRACE_EVENTS+=" -e $EVENT"
done

PROFILE_TITLE=default
TRACE_PLUGIN=
if [ "$MONITOR_FTRACE_PLUGIN" != "" ]; then
	TRACE_PLUGIN="-p $MONITOR_FTRACE_PLUGIN"
	PROFILE_TITLE=$MONITOR_FTRACE_PLUGIN
fi

TRACE_RECORD_COMMAND="record -a $TRACE_EVENTS $TRACE_PLUGIN"
TRACE_REPORT_COMMAND=

gcc -Wall /tmp/mmtests-wait.c -o /tmp/mmtests-wait || exit $SHELLPACK_ERROR

echo "#!/bin/bash" > monitor-pre-hook
echo "
trace-cmd $TRACE_RECORD_COMMAND -o \$1/trace-cmd-\$2-report-${PROFILE_TITLE}.data &
echo -n Waiting on ftrace to start
while [ ! -e \$1/trace-cmd-\$2-report-${PROFILE_TITLE}.data.cpu0 ]; do
	echo -n .
	sleep 1
done
echo
sleep 5
echo \$! > /tmp/mmtests.trace-cmd.pid
" >> monitor-pre-hook

echo "#!/bin/bash" > monitor-post-hook
echo 'WAITPID=`cat /tmp/mmtests.trace-cmd.pid`' >> monitor-post-hook
# use SIGINT to stop trace-cmd record
echo 'kill -s 2 $WAITPID' >> monitor-post-hook
echo 'sleep 1' >> monitor-post-hook
echo 'echo Waiting on trace-cmd pid $WAITPID to exit: `date`' >> monitor-post-hook
echo 'while [ "`ps h --pid $WAITPID`" != "" ]; do' >> monitor-post-hook
echo 'echo -n .' >> monitor-post-hook
echo 'sleep 1' >> monitor-post-hook
echo 'done' >> monitor-post-hook
echo 'echo trace-cmd exited: `date`' >> monitor-post-hook
if [ "$TRACE_REPORT_COMMAND" != "" ]; then
	echo "trace-cmd $TRACE_REPORT_COMMAND -i \$1/trace-cmd-\$2-report-${PROFILE_TITLE}.data > \$1/trace-cmd-\$2-report-${PROFILE_TITLE}.txt" >> monitor-post-hook
	echo "gzip \$1/trace-cmd-\$2-report-${PROFILE_TITLE}.txt" >> monitor-post-hook
fi
echo "gzip \$1/trace-cmd-\$2-report-${PROFILE_TITLE}.data" >> monitor-post-hook
echo "exit 0" >> monitor-post-hook

echo "#!/bin/bash" > monitor-cleanup-hook

echo "#!/bin/bash" > monitor-reset
echo 'kill `cat /tmp/mmtests.wait.pid`' >> monitor-reset
echo "sleep 5" >> monitor-reset

chmod u+x monitor-*
