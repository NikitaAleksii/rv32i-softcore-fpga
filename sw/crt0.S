// This file copies data from ROM to RAM. 
//
// crt0.S because:
//                crt0 - C Runtime, file zero
//                .S   - naming convention means that this file gets run through the C preprocessor first

// Naming Conventions
//      _s - start of a section
//      _d - end of a section
//      _lma_ - load memory address
//      _global_pointer$ - GCC/ABI convention used for GP-relative addressing

// Places code at the beginning
.section .text.entry

// Makes _start externally visible
.global _start

// Expects external main
.extern main

// _start is the traditional name for the entry point in the ELF binary format
_start:
    // Initialize global pointer
    la gp, __global_pointer$

    // Initialize stack pointer
    la sp, _stack_top

// Copy data from LMA to VMA

// Copy small data
sdata_copy:               
    la t0, _ssdata          // Destination
    la t1, _lma_sdata       // Source
    la t3, _esdata
1:  beq t0, t3, data_copy
    lbu t2, 0(t1)
    sb t2, 0(t0)
    addi t0, t0, 1
    addi t1, t1, 1
    j 1b

// Copy any other data
data_copy:
    la t0, _sdata
    la t1, _lma_data
    la t3, _edata
2:  beq t0, t3, sbss_init
    lbu t2, 0(t1)
    sb t2, 0(t0)
    addi t0, t0, 1
    addi t1, t1, 1
    j 2b

// Copy small uninitialized values
sbss_init:
    la t0, _ssbss
    la t3, _esbss
3:  beq t0, t3, bss_init
    sb zero, 0(t0)
    addi t0, t0, 1
    j 3b

// Copy other uninitialized values
bss_init:
    la t0, _sbss
    la t3, _ebss
4:  beq t0, t3, ready
    sb zero, 0(t0)
    addi t0, t0, 1
    j 4b

ready:
    call main

5:
    // Infinite loop
    j 5b