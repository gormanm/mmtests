#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>

static inline uint64_t timeval_to_ms(struct timeval *tv)
{
	return (((uint64_t)tv->tv_sec * 1000000) + tv->tv_usec) / 1000;
}

int main(int argc, char **argv)
{
	void *p, *map;
	int flags, fd = 0;
	int stride = getpagesize();
	unsigned long memfault_size;
	struct timeval tv_start, tv_end;

	if (argc == 1) {
		printf("Specify fault size\n");
		exit(-1);
	}
	memfault_size = atol(argv[1]);

	flags = MAP_ANONYMOUS | MAP_PRIVATE;
	if (argc > 2) {
		fd = open(argv[2], O_CREAT|O_TRUNC|O_RDWR, S_IRWXU);
		if (fd < 0) {
			perror("open");
			exit(EXIT_FAILURE);
		}

		if (ftruncate(fd, memfault_size)) {
			perror("ftruncate");
			exit(EXIT_FAILURE);
		}
		flags = MAP_SHARED;
		unlink(argv[1]);
	}

	map = mmap(NULL, memfault_size, PROT_READ | PROT_WRITE,
		   flags, fd, 0);
	if (map == MAP_FAILED) {
		perror("mmap");
		exit(EXIT_FAILURE);
	}

	while (1) {
		struct timeval tv_start, tv_end;

		gettimeofday(&tv_start, NULL);
		for (p = map; p < (map + memfault_size); p += stride)
			*(volatile unsigned long *)p = (unsigned long)p;
		gettimeofday(&tv_end, NULL);

		printf("%d\n", timeval_to_ms(&tv_end) - timeval_to_ms(&tv_start));
		sleep(5);
	}

	pause();
	exit(EXIT_SUCCESS);
}

