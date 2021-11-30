#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <string.h>
#include <sched.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>

struct timeval begin, end;
pid_t child_pid;

struct datum {
	unsigned long long latency;
	int parent_cpu;
	int child_cpu;
};

void tvsub(struct timeval *tdiff, struct timeval *t1, struct timeval *t0)
{
	tdiff->tv_sec = t1->tv_sec - t0->tv_sec;
	tdiff->tv_usec = t1->tv_usec - t0->tv_usec;
	if (tdiff->tv_usec < 0 && tdiff->tv_sec > 0) {
		tdiff->tv_sec--;
		tdiff->tv_usec += 1000000;
		assert(tdiff->tv_usec >= 0);
	}

	if (tdiff->tv_usec < 0 || t1->tv_sec < t0->tv_sec) {
		tdiff->tv_sec = 0;
		tdiff->tv_usec = 0;
	}
}

unsigned long long tvdelta(struct timeval *begin, struct timeval *end)
{
	struct timeval td;
	unsigned long long usecs;

	tvsub(&td, end, begin);
	usecs = td.tv_sec;
	usecs *= 1000000;
	usecs += td.tv_usec;
	return usecs;
}

void do_forkexit(unsigned int iterations, struct datum* results)
{
	struct timeval begin, end;
	int parent_cpu, child_cpu = -1;
	int i, wstatus;

	for (i = 0; i < iterations; i++) {
		parent_cpu = sched_getcpu();
		gettimeofday(&begin, (struct timezone *) 0);

		switch (child_pid = fork()) {
		case -1:
			perror("fork");
			exit(1);

		case 0:	/* child */
			exit(sched_getcpu());

		default:
			waitpid(child_pid, &wstatus, 0);
			gettimeofday(&end, (struct timezone *) 0);
		}

		if (WIFEXITED(wstatus))
			child_cpu = WEXITSTATUS(wstatus);

		results[i].latency = tvdelta(&begin, &end);
		results[i].parent_cpu = parent_cpu;
		results[i].child_cpu = child_cpu;

		child_pid = 0;
	}
}

void presults(unsigned int iterations, struct datum* results)
{
	int i;

	printf("PARENT  CHILD   LATENCY\n");

	for (i = 0; i < iterations; i++) {
		printf("%03d     %03d     %llu\n", results[i].parent_cpu,
			results[i].child_cpu, results[i].latency);
	}
}

int main(int argc, char *argv[]) {
	int iters;
	size_t res_size;
	struct datum *results;

	if (argc < 2) {
		printf("Missing argument.\n");
		printf("USAGE: %s ITERS\n", argv[0]);
		return 1;
	}

	iters = atoi(argv[1]);
	res_size = iters * sizeof(struct datum);
	results = malloc(res_size);
	memset(results, 0, res_size);

	do_forkexit(iters, results);

	presults(iters, results);
	return 0;
}
