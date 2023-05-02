/*
 * This benchmark is designed to stress THP allocation and compaction. It does
 * not guarantee that THP allocations take place and it's up to the user to
 * monitor system activity and check that the relevant paths are used.
 */
#define _LARGEFILE64_SOURCE
#include <fcntl.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <numaif.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/syscall.h>

#define PAGESIZE getpagesize()
#define HPAGESIZE (1048576*2)
#define __ALIGN_MASK(x, mask)    (((x) + (mask)) & ~(mask))
#define ALIGN(x, a)            __ALIGN_MASK(x, (typeof(x))(a) - 1)
#define PTR_ALIGN(p, a)         ((typeof(p))ALIGN((unsigned long)(p), (a)))
#define HPAGE_ALIGN(p)          PTR_ALIGN(p, HPAGESIZE)

size_t anon_size, file_size;
size_t anon_thread_size, file_thread_size;
unsigned long *anon_init;
unsigned long *file_init;
int nr_hpages;
int madvise_huge;
char *filename;

/* barrier for all threads to finish initialisation on */
static pthread_barrier_t init_barrier;

static inline uint64_t timeval_to_us(struct timeval *tv)
{
	return ((uint64_t)tv->tv_sec * 1000000) + tv->tv_usec;
}

static inline int current_nid() {
#ifdef SYS_getcpu
	int cpu, nid, ret;

	ret = syscall(SYS_getcpu, &cpu, &nid, NULL);
	return ret == -1 ? -1 : nid;
#else
	return -1;
#endif
}

struct fault_timing {
	bool hugepage;
	struct timeval tv;
	uint64_t latency;
	int locality;
};

static struct fault_timing **timings;

static void *worker(void *data)
{
	int thread_idx = (unsigned long *)data - anon_init;
	size_t i, offset;
	int fd, sum = 0;
	char *first_mapping, *second_mapping, *file_mapping;
	char *aligned, *end_mapping;
	struct timeval tv_start, tv_end;
	size_t second_size;
	int task_nid, memory_nid;

	second_size = anon_thread_size / 2;

	gettimeofday(&tv_start, NULL);

	/* Create a large mapping */
	first_mapping = mmap(NULL, anon_thread_size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, 0, 0);
	if (first_mapping == MAP_FAILED) {
		perror("First mapping");
		exit(EXIT_FAILURE);
	}
	madvise(first_mapping, anon_thread_size, MADV_HUGEPAGE);
	memset(first_mapping, 1, anon_thread_size);

	/* Align index to huge page boundary */
	end_mapping = first_mapping + anon_thread_size;
	aligned = HPAGE_ALIGN(first_mapping);
	i = aligned - first_mapping;

	/* Punch holes */
	for (; aligned + HPAGESIZE/2 < end_mapping; aligned += HPAGESIZE) {
		munmap(aligned, HPAGESIZE/2);
	}

	/* Allocate second mapping but do not fault it */
	second_mapping = mmap(NULL, second_size + HPAGESIZE, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, 0, 0);
	if (second_mapping == MAP_FAILED) {
		perror("Second mapping");
		exit(EXIT_FAILURE);
	}
	aligned = HPAGE_ALIGN(second_mapping);
	offset = aligned - second_mapping;
	end_mapping = second_mapping + second_size;

	if (madvise_huge) {
		printf("Using madv_hugepage 0x%lu %lu gb\n", (unsigned long)second_mapping, (second_size + HPAGESIZE)/1048576/1024);
		madvise(second_mapping, second_size + HPAGESIZE, MADV_HUGEPAGE);
	} else {
		printf("Using default advice\n");
	}

	/* Record anon init timings */
	gettimeofday(&tv_end, NULL);
	anon_init[thread_idx] = timeval_to_us(&tv_end) - timeval_to_us(&tv_start);

	/* Fill holes with file pages. Do not include in anon init timings */
	gettimeofday(&tv_start, NULL);
	if ((fd = open(filename, O_LARGEFILE|O_RDONLY, 0)) == -1) {
		perror("open");
		exit(EXIT_FAILURE);
	}
	printf("File %d Size 0x%lX Offset 0x%lX\n", thread_idx, file_thread_size, file_thread_size*thread_idx);
	file_mapping = mmap(NULL, file_thread_size, PROT_READ, MAP_SHARED, fd, file_thread_size*thread_idx);
	if (file_mapping == MAP_FAILED) {
		perror("File mapping");
		exit(EXIT_FAILURE);
	}
	for (i = 0; i < file_thread_size; i += PAGESIZE)
		sum += file_mapping[i];

	/* Record file init timings */
	gettimeofday(&tv_end, NULL);
	file_init[thread_idx] = timeval_to_us(&tv_end) - timeval_to_us(&tv_start);

	printf("Artifical sum for offset 0x%016lX: %d\n", file_thread_size * thread_idx, sum);
	fflush(NULL);

	/* Wait for all threads to init */
	pthread_barrier_wait(&init_barrier);

	/* Fault the second mapping and record timings */
	for (i = 0; i < nr_hpages; i++) {
		unsigned char vec;
		size_t arridx = offset + i * HPAGESIZE;
		int ret;

		gettimeofday(&tv_start, NULL);
		second_mapping[arridx] = 1;

		/* Check if the fault is THP or not */
		mincore(&second_mapping[arridx + PAGESIZE*64], PAGESIZE, &vec);
		timings[thread_idx][i].hugepage = vec;

		/* Measure time to fill a THPs worth of memory */
		memset(&second_mapping[arridx], 2, HPAGESIZE);

		/* Total latency is time to fault and write */
		gettimeofday(&timings[thread_idx][i].tv, NULL);

		/*
		 * Check locality, this is approximate as task could have
		 * migrated during the fault.
		 */
		task_nid = current_nid();
		ret = get_mempolicy(&memory_nid, NULL, 0, &second_mapping[arridx], MPOL_F_NODE|MPOL_F_ADDR);
		if (ret == -1)
			timings[thread_idx][i].locality = -1;
		else
			timings[thread_idx][i].locality = (memory_nid == task_nid) ? 1 : 0;

		/* Record the latency */
		timings[thread_idx][i].latency = timeval_to_us(&timings[thread_idx][i].tv) - timeval_to_us(&tv_start);
	}

	/* Cleanup */
	munmap(file_mapping, file_thread_size);
	munmap(first_mapping, anon_thread_size);
	munmap(second_mapping, second_size);
	close(fd);

	return NULL;
}

int main(int argc, char **argv)
{
	pthread_t *th;
	int nr_threads, i, j;
	if (argc != 6) {
		printf("Usage: thpcompact [nr_threads] [anon_size] [file_size] [filename] [madvise_hugepage]\n");
		exit(EXIT_FAILURE);
	}

	nr_threads = atoi(argv[1]);
	anon_size = atol(argv[2]);
	file_size = atol(argv[3]);
	filename = argv[4];
	madvise_huge = atoi(argv[5]);
	printf("Running with %d thread%c\n", nr_threads, nr_threads > 1 ? 's' : ' ');
	anon_init = malloc(nr_threads * sizeof(unsigned long));
	if (anon_init == NULL) {
		printf("Unable to allocate anon_init\n");
		exit(EXIT_FAILURE);
	}

	file_init = malloc(nr_threads * sizeof(unsigned long));
	if (file_init == NULL) {
		printf("Unable to allocate file_init\n");
		exit(EXIT_FAILURE);
	}

	nr_hpages = anon_size / nr_threads / HPAGESIZE / 2;
	anon_thread_size = (anon_size / nr_threads) & ~(HPAGESIZE-1);
	file_thread_size = (file_size / nr_threads) & ~(HPAGESIZE-1);

	printf("Nr Threads:       %d\n",	nr_threads);
	printf("Thread anon size: %lu\n",	anon_thread_size);
	printf("Thread file size: %lu\n",	file_thread_size);

	th = malloc(nr_threads * sizeof(pthread_t));
	if (th == NULL) {
		printf("Unable to allocate thread structures\n");
		exit(EXIT_FAILURE);
	}

	timings = malloc(nr_threads * sizeof(struct fault_timing *));
	if (timings == NULL) {
		printf("Unable to allocate timings structure\n");
		exit(EXIT_FAILURE);
	}

	pthread_barrier_init(&init_barrier, NULL, nr_threads);
	for (i = 0; i < nr_threads; i++) {
		timings[i] = malloc(nr_hpages * sizeof(struct fault_timing));
		if (timings[i] == NULL) {
			printf("Unable to allocate timing for thread %d\n", i);
			exit(EXIT_FAILURE);
		}
		if (pthread_create(&th[i], NULL, worker, &anon_init[i])) {
			perror("Creating thread");
			exit(EXIT_FAILURE);
		}
	}

	for (i = 0; i < nr_threads; i++)
		pthread_join(th[i], NULL);
	pthread_barrier_destroy(&init_barrier);

	printf("\n");
	for (i = 0; i < nr_threads; i++)
		printf("anoninit %d %12lu\n", i, anon_init[i]);

	for (i = 0; i < nr_threads; i++)
		printf("fileinit %d %12lu\n", i, file_init[i]);

	for (i = 0; i < nr_threads; i++)
		for (j = 0; j < nr_hpages; j++)
			printf("fault %d %s %12lu %lu.%lu %d\n", i,
				timings[i][j].hugepage ? "huge" : "base",
				timings[i][j].latency,
				timings[i][j].tv.tv_sec,
				timings[i][j].tv.tv_usec,
				timings[i][j].locality);

	return 0;
}

