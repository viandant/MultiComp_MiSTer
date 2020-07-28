CC=arm-linux-gnueabihf-gcc

# Remove newlines from Forth sources
%.fss: %.fs
	tr  '\n' ' ' < $< > $@

upload_shram: file2multi shram.fss
	./file2multi shram.fss

psexp: psexp.c secdmem.o
runsecd: runsecd.c secdmem.o
