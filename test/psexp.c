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

#define SYMTABLE_MAX 4096
#define SYMMAP_MAX 1024

static volatile char * shmem_base = 0;

char symtable[SYMTABLE_MAX];
unsigned int symmap[SYMMAP_MAX];

void usage(const char * progname) {
  fprintf(stderr, "Usage: %s <Start address> [<symbol table file>]\n",
			 progname);
  exit(2);
}

uint32_t deref(uint16_t ptr) {
  return * (uint32_t *)(shmem_base + 8 * ptr);
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
		printf(symtable + symmap[cdr(sexp) - 1]);
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
  
  if ( (argc != 2) && (argc != 3) )
	 usage(argv[0]);
  
  shmem_base = shmem_init();
  if (shmem_base == 0)
    exit(1);
  
  int sexp = strtol(argv[1],NULL,0);

  if (argc > 2) {
	 int symstream = open(argv[2], O_RDONLY);
	 if (symstream < 0) {
		fprintf(stderr, "Could not open symbol table file.\n");
		exit(3);
	 }

	 ssize_t symtable_sz = read(symstream, symtable, SYMTABLE_MAX);
	 if (symtable_sz < 0) {
		fprintf(stderr, "Could not read symbol table.\n");
		exit(5);
	 }
	 if (symtable_sz == SYMTABLE_MAX) {
		char c;
		if (read(symstream, &c, 1) != 0) {
		  fprintf(stderr, "Sorry, the total length of all symbol names exhausts the implemented space.\n");
		  exit(6);
		}
	 }
	 close(symstream);
	 
	 int i,j;
	 j = 0;
	 for (i=0; i < symtable_sz; i++) {
		if (symtable[i] == 0) {
		  symmap[j] = i+1;
		  j++;
		  if (j > SYMMAP_MAX) {
			 fprintf(stderr, "Sorry, the symbol table is not implemented for more than %i symbols.", SYMMAP_MAX);
			 exit(4);
		  }
		}
	 }
	 symmap[j] = symtable_sz+1;
	 close(symstream);
  }
  
  
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
