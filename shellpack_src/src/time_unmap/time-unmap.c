#define _GNU_SOURCE
#include <errno.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <string.h>

#include <sys/mman.h>
#include <sys/time.h>
#include <sys/wait.h>

#define MAXCPUS 4096

struct thread_data {
	int tindex;
	int cpu;
	size_t thread_buf_size;
	char *thread_buf;
};

static int cpu_set_size;
static struct thread_data *thread_data;
static pthread_t *threads;

static void pin(int cpu)
{
	cpu_set_t *affinity;

	if (cpu < 0 || cpu >= MAXCPUS)
		return;

	affinity = CPU_ALLOC(MAXCPUS);
	CPU_ZERO_S(cpu_set_size, affinity);
	CPU_SET_S(cpu, cpu_set_size, affinity);
	(void)sched_setaffinity(0, cpu_set_size, affinity);
	CPU_FREE(affinity);
	return;
}

static void *thread_fault(void *data)
{
	struct thread_data *td = (struct thread_data *)data;

	pin(td->cpu);
	memset(td->thread_buf, td->tindex, td->thread_buf_size);

	return NULL;
}

/* Time difference in microseconds */
unsigned long long time_diff(struct timeval *start, struct timeval *end)
{
	return ((unsigned long long)(end->tv_sec - start->tv_sec)) * 1000000 +
                end->tv_usec - start->tv_usec;
}

int main(int argc, char **argv)
{
	int nr_threads = 1;
	size_t shared_buf_size = 0;
	int i, j;
	struct timeval tv_start, tv_end;
	char opt;
	char *shared_buf;
	int nr_online_cpus =0;
	int *online_cpus;
	cpu_set_t *task_affinity;

	while ((opt = getopt(argc, argv, "n:s:")) != -1) {
		switch (opt) {
		case 'n':
			nr_threads = atoi(optarg);
			break;
		case 's':
			shared_buf_size = atol(optarg);
			break;
		default:
			fprintf(stderr, "Usage: time-unmap [-n nr_threads] -s <mmap_size>\n");
		}
	}
	if (!shared_buf_size) {
		printf("Usage: time-unmap [-n nr_threads] -s <mmap_size>\n");
		exit(-1);
	}
	shared_buf_size += 1048576;
	shared_buf_size &= ~((2*1048576)-1);

	cpu_set_size = CPU_ALLOC_SIZE(MAXCPUS);
	task_affinity = CPU_ALLOC(MAXCPUS);
	if (sched_getaffinity(0, cpu_set_size, task_affinity) < 0) {
		perror("sched_getaffinity");
		exit(-2);
	}

	shared_buf = mmap(0, shared_buf_size, PROT_READ | PROT_WRITE,
			MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
	if (shared_buf == MAP_FAILED) {
		perror("mmap");
		exit(-1);
	}

	threads = malloc(nr_threads * sizeof(struct pthread_t *));
	if (!threads) {
		printf("Insufficient memory to allocate thread pointers\n");
		exit(-1);
	}

	thread_data = malloc(nr_threads * sizeof(struct thread_data));
	if (!thread_data) {
		printf("Insufficient memory to allocate thread_data structs\n");
		exit(-1);
	}

	/* Get CPU IDs of online CPUs */
	online_cpus = malloc(MAXCPUS * sizeof(int));
	if (!online_cpus) {
		printf("Insufficient memory to allocate online CPUs\n");
	}
	for (i = 0, j = 0; i < cpu_set_size; i++) {
		if (CPU_ISSET(i, task_affinity)) {
			online_cpus[j] = i;
			nr_online_cpus++;
			j++;
		}
	}

	for (i = 0; i < nr_threads; i++) {
		struct thread_data *td = &thread_data[i];

		td->tindex = i;
		td->cpu = online_cpus[i % nr_online_cpus];
		td->thread_buf_size = shared_buf_size / nr_threads;
		td->thread_buf = shared_buf + (td->thread_buf_size * i);

		if (pthread_create(&threads[i], NULL, thread_fault, td)) {
			perror("Thread create");
			exit(-1);
		}
	}

	for (i = 0; i < nr_threads; i++) {
		pthread_join(threads[i], NULL);
	}

	gettimeofday(&tv_start, NULL);
	munmap(shared_buf, shared_buf_size);
	gettimeofday(&tv_end, NULL);

	printf("%lld\n", time_diff(&tv_start, &tv_end));

	return 0;
}
