.section .text.init
.globl _start
_start:
    # Initialize global pointer (optional but good practice)
.option push
.option norelax
    la gp, __global_pointer$
.option pop

    # Initialize stack pointer
    # Since data memory is 32KB (8192 words) starting from 0 (aliased),
    # let's set the stack pointer to the top of 32KB memory (0x8000)
    li sp, 0x00008000

    # Copy .data section from ROM to RAM
    la t0, __data_load_start
    la t1, __data_start
    la t2, __data_end
1:  bgeu t1, t2, 2f
    lw t3, 0(t0)
    sw t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j 1b
2:

    # Zero out .bss section
    la t0, __bss_start
    la t1, __bss_end
3:  bgeu t0, t1, 4f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 3b
4:

    # Set up trap handler for FreeRTOS
    la t0, freertos_risc_v_trap_handler
    csrw mtvec, t0

    # Jump to C main function
    jal ra, main

    # If main returns, loop infinitely
1:
    j 1b
