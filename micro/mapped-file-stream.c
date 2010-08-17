/*
 * Copyright (c) 2010 Johannes Weiner
 * Code released under the GNU GPLv2.
 */
#include <sys/types.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <limits.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>

static int start_process(unsigned long nr_bytes)
{
	char filename[] = "/tmp/clog-XXXXXX";
	unsigned long i;
	char *map;
	int fd;

	fd = mkstemp(filename);
	unlink(filename);
	if (fd == -1) {
		perror("mkstemp()");
		return -1;
	}

	if (ftruncate(fd, nr_bytes)) {
		perror("ftruncate()");
		return -1;
	}

	map = mmap(NULL, nr_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (map == MAP_FAILED) {
		perror("mmap()");
		return -1;
	}

	if (madvise(map, nr_bytes, MADV_RANDOM)) {
		perror("madvise()");
		return -1;
	}

	kill(getpid(), SIGSTOP);

	for (i = 0; i < nr_bytes; i += 4096)
		((volatile char *)map)[i];

	close(fd);
	return 0;
}

static int do_test(unsigned long nr_procs, unsigned long nr_bytes)
{
	pid_t procs[nr_procs];
	unsigned long i;
	int dummy;

	for (i = 0; i < nr_procs; i++) {
		switch ((procs[i] = fork())) {
		case -1:
			kill(0, SIGKILL);
			perror("fork()");
			return -1;
		case 0:
			return start_process(nr_bytes);
		default:
			waitpid(procs[i], &dummy, WUNTRACED);
			break;
		}
	}

	kill(0, SIGCONT);

	for (i = 0; i < nr_procs; i++)
		waitpid(procs[i], &dummy, 0);

	return 0;
}

static int xstrtoul(const char *str, unsigned long *valuep)
{
	unsigned long value;
	char *endp;

	value = strtoul(str, &endp, 0);
	if (*endp || (value == ULONG_MAX && errno == ERANGE))
		return -1;
	*valuep = value;
	return 0;
}

int main(int ac, char **av)
{
	unsigned long nr_procs, nr_bytes;

	if (ac != 3)
		goto usage;
	if (xstrtoul(av[1], &nr_procs))
		goto usage;
	if (xstrtoul(av[2], &nr_bytes))
		goto usage;
	setbuf(stdout, NULL);
	setbuf(stderr, NULL);
	return !!do_test(nr_procs, nr_bytes);
usage:
	fprintf(stderr, "usage: %s nr_procs nr_bytes\n", av[0]);
	return 1;
}
