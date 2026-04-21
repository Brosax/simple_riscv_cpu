CROSS_COMPILE ?= riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

CFLAGS = -march=rv32i -mabi=ilp32 -O2 -ffreestanding -nostdlib -Wall -Wextra
CFLAGS += -I. -IFreeRTOS/include -IFreeRTOS/portable/GCC/RISC-V

LDFLAGS = -T link.ld -nostartfiles -nostdlib -Wl,--gc-sections

SRCS = start.S main.c \
       FreeRTOS/list.c \
       FreeRTOS/queue.c \
       FreeRTOS/tasks.c \
       FreeRTOS/timers.c \
       FreeRTOS/portable/MemMang/heap_4.c \
       FreeRTOS/portable/GCC/RISC-V/port.c \
       FreeRTOS/portable/GCC/RISC-V/portASM.S

OBJS = $(filter %.o, $(SRCS:.c=.o) $(SRCS:.S=.o))

all: main.mem

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

LIBGCC := $(shell $(CC) $(CFLAGS) -print-libgcc-file-name)

main.elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ $(LIBGCC) -o $@
	$(OBJDUMP) -D $@ > main.dump

main.bin: main.elf
	$(OBJCOPY) -O binary $< $@

main.mem: main.bin
	cd .. && python3 scripts/bin_to_mem.py sw/main.bin rtl/main.mem

clean:
	rm -f $(OBJS) main.elf main.bin main.mem main.dump ../rtl/main.mem