# Pawmodoro Makefile
# Target: 32-bit x86 ELF binary for Linux (no libc, int 0x80)

NASM      ?= nasm
LD        ?= ld
NASMFLAGS ?= -f elf32 -g -F dwarf -Wall
LDFLAGS   ?= -m elf_i386
TARGET    ?= build/pawmodoro

SRCS      := $(wildcard src/*.asm src/*.inc)

.PHONY: all run debug clean

all: $(TARGET)

build/pawmodoro.o: $(SRCS)
	mkdir -p build
	$(NASM) $(NASMFLAGS) src/main.asm -o build/pawmodoro.o

$(TARGET): build/pawmodoro.o
	$(LD) $(LDFLAGS) build/pawmodoro.o -o $(TARGET)

run: all
	./$(TARGET)

debug: all
	gdb ./$(TARGET)

clean:
	rm -rf build
