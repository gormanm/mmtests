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
PROFILE_TITLE="timer"
export PROFILE_EVENTS=timer

PERF_RECORD_COMMAND="record -a"
PERF_REPORT_COMMAND="report"

gcc -Wall /tmp/mmtests-wait.c -o /tmp/mmtests-wait || exit $SHELLPACK_ERROR

echo "#!/bin/bash" > monitor-pre-hook
echo "
perf $PERF_RECORD_COMMAND  -o \$1/perf-\$2-report-${PROFILE_TITLE}.data /tmp/mmtests-wait &
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

echo "#!/bin/bash" > monitor-reset
echo 'kill `cat /tmp/mmtests.wait.pid`' >> monitor-reset
echo "sleep 5" >> monitor-reset

chmod u+x monitor-*
