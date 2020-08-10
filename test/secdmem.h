#ifndef SECDMEM_H
#define SECDMEM_H
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define SHMEM_ADDR 0x30000000
#define SHMEM_SIZE 0x20000
#define SHMEM_MAX  0x20000

volatile char * shmem_init();
#endif
