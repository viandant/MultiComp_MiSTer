// Usage: psexp <Start address>
//
// Prints the s-expression starting at the given address in SECD memory.

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <inttypes.h>
#include <stdio.h>
#include <sys/mman.h>
#include <stdlib.h>
#include "secdmem.h"

static volatile char * shmem_base = 0;

void usage(const char * progname) {
  fprintf(stderr, "Usage: <Start address>%s\n",
			 progname);
  exit(2);
}

uint32_t deref(uint16_t ptr) {
  return * (uint32_t *)(shmem_base + 4 * ptr);
}

uint16_t cdrc(uint32_t cell) {
  return cell & 0x3fff;
}

uint16_t cdr(uint16_t ptr) {
  return cdrc(deref(ptr));
}

uint16_t carc(uint32_t cell) {
  return cell>>14 & 0x3fff;
}

uint16_t car(uint16_t ptr) {
  return carc(deref(ptr));
}

uint16_t typec(uint32_t cell) {
  return cell>>28 & 0x3;
}

uint16_t type(uint16_t ptr) {
  return typec(deref(ptr));
}

int atom(uint16_t sexp) {
  return type(sexp) != 0;
}

void printsexp(uint16_t sexp, int incdr, int withAddr) {
  switch (type(sexp)) {
  case 0:
	 if (withAddr)
		if (incdr)
		  printf(" . #%x:(",sexp);
		else
		  printf("#%x:(",sexp);
	 else
		if (incdr)
		  printf(" ");
		else
		  printf("(");
	 printsexp(car(sexp), 0, withAddr);
	 printsexp(cdr(sexp), -1, withAddr);
	 if (!incdr)
		printf(")");
	 break;
  case 2:
	 switch(cdr(sexp)) {
	 case 0:
		if (!incdr)
		  printf(" nil");
		break;
	 case 1:
		if (incdr)
		  printf(" . ");
		printf("T");
		break;
	 case 2:
		if (incdr)
		  printf(" . ");
		printf("F");
		break;
	 default:

		printf("<sym %x>", cdr(sexp));
	 }
	 break;
  case 3:
	 if (incdr)
		printf(" . ");
	 printf("%i", cdr(sexp));
	 break;
  default:
	 printf("<?%x>", sexp);
  };
}


int  main(int argc, char **argv) {

  int length_sz;
  int8_t opt;
  
  if (argc != 2)
	 usage(argv[0]);
  
  shmem_base = shmem_init();
  if (shmem_base == 0)
    exit(1);
  
  int sexp = strtol(argv[1],NULL,0);

  printf("Reading the S-expression at %x\n", sexp);
  printf(" The value of this memory cell is %x", deref(sexp));
  printf(" representing a ");
  switch (type(sexp)) {
  case 0:
	 printf("cons");
	 break;
  case 2:
	 printf("sym");
	 break;
  case 3:
	 printf("number");
	 break;
  default:
	 printf("Unknonw type");
  };
  printf(".\n");
  printf(" The full S-expression:\n  ");
  printsexp(sexp, 0, 0);
  printf("\n");
  return 0;
}
