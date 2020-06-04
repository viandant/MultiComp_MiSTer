#include "secdmem.h"
volatile char * shmem_init()
{
  volatile char * shmem_base = 0;
  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd == -1)
    {
      printf("Unable to open /dev/mem!\n");
      return 0;
    }

  shmem_base = (volatile char*)mmap(0, SHMEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, SHMEM_ADDR);
  if (shmem_base == (void *)-1)
    {
      printf("Unable to mmap shared memory!\n");
      shmem_base = 0;
    }
  close(fd);
  return shmem_base;
}
