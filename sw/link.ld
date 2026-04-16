OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
    /* Instruction memory 32KB at 0x80000000 */
    ROM (rx)  : ORIGIN = 0x80000000, LENGTH = 32K
    /* Data memory 8KB at 0x00000000 */
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > ROM

    .rodata : {
        *(.rodata .rodata.*)
    } > ROM

    .data : {
        . = ALIGN(4);
        __data_load_start = LOADADDR(.data);
        __data_start = .;
        __global_pointer$ = . + 0x800;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM AT > ROM

    .bss : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    /DISCARD/ : {
        *(.eh_frame)
    }
}
