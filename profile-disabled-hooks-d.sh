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

	fd = open("/tmp/mmtests.perf.pid", O_CREAT|O_TRUNC|O_WRONLY);
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

gcc -Wall /tmp/mmtests-wait.c -o /tmp/mmtests-wait || exit $SHELLPACK_ERROR

echo "#!/bin/bash" > monitor-pre-hook
echo "perf record -o \$1/oprofile-\$2-report-${PROFILE_TITLE}.data -g -a /tmp/mmtests-wait &" >> monitor-pre-hook

echo "#!/bin/bash" > monitor-post-hook
echo 'kill `cat /tmp/mmtests.perf.pid`' >> monitor-post-hook
echo "sleep 5" >> monitor-post-hook
echo "perf report -i \$1/oprofile-\$2-report-${PROFILE_TITLE}.data > \$1/oprofile-\$2-report-${PROFILE_TITLE}.txt" >> monitor-post-hook
echo "gzip \$1/oprofile-\$2-report-${PROFILE_TITLE}.data" >> monitor-post-hook

echo "#!/bin/bash" > monitor-cleanup-hook

echo "#!/bin/bash" > monitor-reset
echo 'kill `cat /tmp/mmtests.perf.pid`' >> monitor-reset
echo "sleep 5" >> monitor-reset

chmod u+x monitor-*
