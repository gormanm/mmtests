#include <stdlib.h>
#include <pthread.h>

void *tspin(void *arg)
{
         while(1);
}

int main(int argc, char** argv)
{
         int i = 0;
         int num_threads = atoi(argv[1]);

         for (i = 0 ; i < num_threads- 1; i++) {
                 pthread_t t;
                 int ret = pthread_create(&t, NULL, tspin, NULL);
         }

         tspin(NULL);
}
