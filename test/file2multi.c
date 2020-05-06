// Usage: file2multi <filename>
//
// Copies content of file to the location in DDRAM
// where it can be accessed from the 6809 Forth computer
// using shared memory.
// The size of the file is written to the first byte for shared RAM.
// The file content follows immediately.
// File size is therefore limited to 256 bytes.
//
// Display the file with the following Forth code:
// HEX B201 B200 C@ TYPE
// Execute it with (beware of line breaks):
// HEX B201 B200 C@ EVALUATE

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <inttypes.h>
#include <stdio.h>
#include <sys/mman.h>
#include <stdlib.h>

#define SHMEM_ADDR 0x30000000
#define SHMEM_SIZE 0x40
#define SHMEM_MAX  0x100

char forthcode[SHMEM_MAX];
static volatile char *shmem_base = 0;

static void shmem_init()
{
  
  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd == -1)
    {
      printf("Unable to open /dev/mem!\n");
      shmem_base = 0;
      return;
    }

  shmem_base = (volatile char*)mmap(0, SHMEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, SHMEM_ADDR);
  if (shmem_base == (void *)-1)
    {
      printf("Unable to mmap shared memory!\n");
      shmem_base = 0;
    }
  close(fd);
}

int  main(int argc, char **argv) {

  if (argc != 2) {
      printf("Usage: file2multi <filename>\n");
      exit(2);
    }

  int inp = open(argv[1], O_RDONLY);

  if (inp < 0) {
    printf("Could not open file.\n");
    exit(3);
  }
  
  shmem_init();
  if (shmem_base == 0)
    exit(1);

  ssize_t sz = read(inp, (void *)shmem_base+1, SHMEM_MAX);
  shmem_base[0] = sz;
  
  close(inp);
  if (sz < 0) {
	 printf("Reading from file failed.");
	 exit(4);
  }
  
  return 0;
}
