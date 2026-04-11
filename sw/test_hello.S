# test_hello.S - Simple RISC-V program to output "Hello FPGA!\n" via tohost
# Assembled for RV32I, using the tohost MMIO address 0x80002000
# Each "sw" to 0x80002000 triggers host_write_enable pulse on the CPU

# Register usage:
#   x8  - tohost address pointer
#   x9  - character data register

.section .text
.global _start

_start:
    lui  x8, 0x80002       # x8 = 0x80002000 (tohost address)

    # Byte 0: 'H' = 0x48
    addi x9, x0, 0x48
    sb   x9, 0(x8)

    # Byte 1: 'e' = 0x65
    addi x9, x0, 0x65
    sb   x9, 0(x8)

    # Byte 2: 'l' = 0x6C
    addi x9, x0, 0x6C
    sb   x9, 0(x8)

    # Byte 3: 'l' = 0x6C
    addi x9, x0, 0x6C
    sb   x9, 0(x8)

    # Byte 4: 'o' = 0x6F
    addi x9, x0, 0x6F
    sb   x9, 0(x8)

    # Byte 5: ' ' = 0x20
    addi x9, x0, 0x20
    sb   x9, 0(x8)

    # Byte 6: 'F' = 0x46
    addi x9, x0, 0x46
    sb   x9, 0(x8)

    # Byte 7: 'P' = 0x50
    addi x9, x0, 0x50
    sb   x9, 0(x8)

    # Byte 8: 'G' = 0x47
    addi x9, x0, 0x47
    sb   x9, 0(x8)

    # Byte 9: 'A' = 0x41
    addi x9, x0, 0x41
    sb   x9, 0(x8)

    # Byte 10: '!' = 0x21
    addi x9, x0, 0x21
    sb   x9, 0(x8)

    # Byte 11: '\n' = 0x0A
    addi x9, x0, 0x0A
    sb   x9, 0(x8)

    # Byte 12: '\r' = 0x0D
    addi x9, x0, 0x0D
    sb   x9, 0(x8)

    # Pause briefly (count to some value)
    addi x10, x0, 1
count_loop:
    addi x10, x10, -1
    bnez x10, count_loop

    # Loop back to start
    jal x0, _start

    # Should never reach here
    ebreak
