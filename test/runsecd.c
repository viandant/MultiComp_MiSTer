// Runs the SECD machine with the code from file code.bin
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <poll.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include "secdmem.h"

#define BUFSIZE 128

static char buf[BUFSIZE];
static FILE * fin;
static int fdout;
static volatile char * shmem_base = 0;

void send_cmd(char * cmd) {
  write(fdout, cmd, strlen(cmd));
  fgets(buf, BUFSIZE, fin);
};

void getoutput (FILE *forth) {
  fgets(buf, BUFSIZE, forth);
}

void discard(int fd) {
  struct pollfd polldata;
  polldata.fd = fd;
  polldata.events = POLLIN;
  
  poll(&polldata, 1, 10);
  while (polldata.revents & POLLIN)
	 {
		putchar('*');
		read(fd, buf, BUFSIZE);
		poll(&polldata, 1, 10);
	 }
}

void print_state(int letter) {
  static char unknown[] = "???";
  static char running[] = "running";
  static char halted[]  = "waiting for button and ";
  static char gc[]      = "garbage collecting and ";
  static char stopped[] = "stopped";
  static char none[]    = "";
  
  char* main_state_txt = "unknown and";
  char* stopped_txt = "none";
  u_int8_t state = buf[strlen(buf) - 6] - 0x30;

  if (letter)
	 switch (state) {
	 case 0:
		putchar('.');
		break;
	 case 2:
		putchar('*');
		break;
	 case 4:
		putchar('|');
		break;
	 default:
		putchar('?');
		break;
	 }
  else {
	 switch ((state & 0x3)) {
	 case 0: main_state_txt = none;
		break;
	 case 1: main_state_txt = halted;
		break;
	 case 2: main_state_txt = gc;
		break;
	 default: main_state_txt = unknown;
		break;
	 };
	 
	 if ((state & 0x4) == 0x4)
		stopped_txt = stopped;
	 else
		stopped_txt = running;
	 
	 printf(" -> SECD state: %x %s%s", state, main_state_txt, stopped_txt);
  }
}
  
 
int main () {
  
  fdout = open("/dev/ttyS1", O_WRONLY );
  if (fdout < 0) {
	 printf("Can't open serial interface to front machine.\n");
	 return 1;
  };

  int fdin = open("/dev/ttyS1", O_RDONLY  );
  if (fdin < 0) {
	 printf("Can't open serial interface to front machine.\n");
	 return 1;
  };  
  struct termios options;
  
  printf("Opened serial interface to front machine ...\n");
  
  tcgetattr(fdout, &options);
  options.c_cflag |= (CREAD | CLOCAL);
  options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
  options.c_iflag &= ~(IXON | IXOFF | IXANY );
  options.c_iflag |= IGNCR;
  options.c_cflag &= ~CRTSCTS;
  options.c_oflag &= ~OPOST;
  options.c_cc[VMIN] = 1;
  options.c_cc[VTIME] = 3;
  cfsetospeed(&options, B115200);
  cfsetispeed(&options, B115200);
  tcsetattr(fdout, TCSANOW, &options);

  printf("Discarding old output from front machine ...\n");
  discard(fdin);
  fin = fdopen(fdin, "r");
  if (fin == NULL)
    {
      perror("Unable to open serial interface to Forth machine.");
      return 0;
    }

  shmem_base = shmem_init();
  if (shmem_base == 0)
    exit(1);

  send_cmd("\r\n");
  send_cmd("HEX \r\n");
  send_cmd("B140 C@ . \r\n");
  print_state(0);
  printf("\nStopping SECD machine...\n");
  send_cmd("1 B140 C! B140 C@ . \r\n");
  print_state(0);
  printf("\nResetting ...\n");
  send_cmd("1 B144 C! \r\n");
  send_cmd("B140 C@ . \r\n");
  print_state(0);
  printf("\n");
  int code_in = open("code.bin", O_RDONLY);
  if (code_in < 0) {
    printf("Could not open code file.\n");
    exit(3);
  }
  printf("Writing problem into memory...\n");
  ssize_t sz = read(code_in, (void *)shmem_base, SHMEM_MAX);
  if (sz < 0) {
	 printf("Reading from code file failed.");
	 exit(4);
  }
  printf("Starting ...\n");
  printf("Releasing stop signal ...\n");
  send_cmd("0 B140 C! B140 C@ . \r\n");
  print_state(0);
  do {
	 printf("\nPressing button ...\n");
	 send_cmd("2 B140 C! B140 C@ . \r\n");
	 print_state(0);
  } while (buf[strlen(buf) - 6] == '1');
  printf("\nMachine is running, waiting for completion ...\n");
  do {
	 send_cmd("B140 C@ . \r\n");
	 print_state(1);
  } while (buf[strlen(buf) - 6] != '4');
  printf("Machine stopped.\n");
  close(code_in);
  close(fdout);
  fclose(fin);

  printf("Reading the result from shared memory ...\n");
  execl("psexp", "psexp", "0x3fff", NULL);
 }
