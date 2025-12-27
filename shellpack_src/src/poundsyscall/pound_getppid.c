#include <stdio.h>
#include <pthread.h>
#include <sys/times.h>
#include <sys/types.h>
#include <unistd.h>

struct tms start;

void *pound (void *threadid)
{
	int i, j = 0;
	for (i = 0; i < 20000000; i++) {
		j += (int)getppid();
	}
	pthread_exit(NULL);
}

int main()
{
	pthread_t th[NUM_THREADS];
	long i;
	times(&start);
	for (i = 0; i < NUM_THREADS; i++) {
		pthread_create (&th[i], NULL, pound, (void *)i);
	}
	pthread_exit(NULL);
	return 0;
}
