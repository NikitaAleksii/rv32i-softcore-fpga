/* 32KB of RAM and 32KB of ROM  */

MEMORY 
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x8000
    RAM (rwx) : ORIGIN = 0x00008000, LENGTH = 0x8000
}

ENTRY(_start)

SECTIONS
{
  .text : {
    _stext = .;
    KEEP(*(.isr_vector))
    *(.text.entry)
    *(.text*)
    _etext = .;
  } > ROM

  .rodata : {
    _srodata = .;
    *(.rodata*)
    *(.srodata*)
    _erodata = .;
  } > ROM

  /* Small data sections (for GP-relative addressing, +- 2KB from __global_pointer$) */
  .sdata : AT(LOADADDR(.rodata) + SIZEOF(.rodata)) {
    . = ALIGN(4);
    _ssdata = .;
    __global_pointer$ = . + 0x800;
    *(.sdata*)
    . = ALIGN(4);
    _esdata = .;
  } > RAM

  .sbss (NOLOAD) : {
    . = ALIGN(4);
    _ssbss = .;
    *(.sbss*)
    . = ALIGN(4);
    _esbss = .;
  } > RAM

  /* Regular data sections */
  .data : AT(LOADADDR(.sdata) + SIZEOF(.sdata)) {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)
    . = ALIGN(4);
    _edata = .;
  } > RAM

  .bss (NOLOAD) : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > RAM

  /* Stack top */
  PROVIDE(_stack_top = ORIGIN(RAM) + LENGTH(RAM));

  /* Heap bottom */
  PROVIDE(_heap_start = _ebss);
  PROVIDE(_heap_end = ORIGIN(RAM) + LENGTH(RAM));

  /* Location of .data in the LMA (_sdata is the location in VMA) */
  _lma_sdata = LOADADDR(.sdata);
  _lma_data = LOADADDR(.data);
}
