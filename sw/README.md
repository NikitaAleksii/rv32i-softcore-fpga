# sw/

C firmware for the RV32I softcore. Compiles bare-metal C to a `.mem` file that the RTL simulation loads into ROM.

## Prerequisites

```bash
# RISC-V GCC cross-compiler
sudo apt install gcc-riscv64-unknown-elf
```

## Workflow

### 1. Build the firmware

```bash
make firmware LIBC=1
```

This runs three steps internally:
- GCC compiles `crt0.S + main.c + uart.c` -> `firmware.elf`
- `objcopy` strips the ELF to a flat binary -> `firmware.bin`. Throws all  metadata away and outputs only the raw bytes of a program, exactly as they should appear in memory, in order.
- `hexdump` converts to hex words -> `firmware.mem`

`LIBC=1` links newlib nano and includes `syscalls.c`, which is required for `printf`, `getchar`, and any other stdio. Without it, linking will fail.

### 2. Copy to the project root

```bash
cp firmware.mem ../
```

The RTL simulation and synthesis both read `firmware.mem` from the project root.

### 3. Run in simulation

From the **project root**:

```bash
make run TOP_TB=firmware_tb
```

This uses `firmware_tb.sv` which taps the internal UART write signal directly and prints each byte to the terminal the moment the processor writes to `0x10000000`. Much faster than decoding real serial bitstream.

## Memory Map

| Region | Address | Size | Contents |
|--------|---------|------|----------|
| ROM | `0x0000_0000 – 0x0000_7FFF` | 32 KB | `.text`, `.rodata` |
| RAM | `0x0000_8000 – 0x0000_FFFF` | 32 KB | `.data`, `.bss`, stack |
| UART TX | `0x1000_0000` | 1 byte | Write byte to transmit |
| UART Status | `0x1000_0004` | 1 word | See bits below |
| UART RX | `0x1000_0008` | 1 byte | Read received byte |

UART status bits: `[0]` tx_busy, `[1]` rx_empty, `[2]` rx_full, `[3]` tx_empty, `[4]` tx_full.

## Startup

`crt0.S` runs before `main()` and:
- Initializes the global pointer (`gp`) and stack pointer (`sp`)
- Copies `.sdata` and `.data` from ROM (LMA) to RAM (VMA)
- Zero-initializes `.sbss` and `.bss`
- Calls `main()`
- Infinite loops on return

## UART Driver

`uart.c` implements `_write()` and `_read()` by directly memory-mapping the UART registers. `syscalls.c` wraps these as newlib syscalls so that `printf` and `getchar` route through them automatically.

## Files

| File | Description |
|------|-------------|
| `main.c` | Application entry point |
| `crt0.S` | Startup code, runs before `main()` |
| `uart.c` / `uart.h` | Low-level UART driver |
| `syscalls.c` | Newlib syscall stubs (`_write`, `_read`, `_sbrk`, etc.) |
| `linker.ld` | Linker script for FPGA (ROM + RAM split) |
| `Makefile` | Build system |