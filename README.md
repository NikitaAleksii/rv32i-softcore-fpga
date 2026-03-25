# rv32i-softcore-fpga

RV32I RISC-V softcore processor implemented in SystemVerilog.

## Architecture

The SoC is composed of a processor core, block RAM for ROM and RAM, and a UART peripheral.

The **processor** is a 6-stage FSM: `INIT → FETCH → DECODE → EXECUTE → MEMORY → WRITE_BACK`. Each instruction takes one pass through the pipeline. The decoder extracts opcodes, register addresses, and all immediate formats from the 32-bit instruction word. The ALU handles arithmetic, logic, shifts, and produces comparison flags for branches. Load and store helpers handle sub-word access - byte and halfword extraction, sign extension, and write mask generation.

The **UART** has independent TX and RX paths, each backed by a 16-entry FIFO. A baud rate generator produces clock enables at the correct rate for both paths. The transmitter and receiver are separate state machines that read from and write to their respective FIFOs.

The **block RAM** (`bram_sdp`) is a simple dual-port design - one synchronous write port, one synchronous read port - with a 4-bit byte write mask. It is instantiated twice: once for ROM (initialized from `firmware.mem`, write-disabled) and once for RAM.

## Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt install iverilog gtkwave
```

**macOS (Homebrew):**
```bash
brew install icarus-verilog gtkwave
```

## Running Firmware

Build the C firmware first (see `sw/README.md`), then copy it to the project root.

```bash
make run TOP_TB=firmware_tb
```

`firmware_tb.sv` taps the internal UART write signal directly rather than decoding the serial bitstream, so output appears immediately in the terminal without waiting for baud rate timing.

## Memory Map

| Region | Address | Size | Contents |
|--------|---------|------|----------|
| ROM | `0x0000_0000 – 0x0000_7FFF` | 32 KB | `.text`, `.rodata` |
| RAM | `0x0000_8000 – 0x0000_FFFF` | 32 KB | `.data`, `.bss`, stack |
| UART TX | `0x1000_0000` | 1 byte | Write byte to transmit |
| UART Status | `0x1000_0004` | 1 word | See bits below |
| UART RX | `0x1000_0008` | 1 byte | Read received byte |

UART status bits: `[0]` tx_busy, `[1]` rx_empty, `[2]` rx_full, `[3]` tx_empty, `[4]` tx_full.

## Files

| File | Description |
|------|-------------|
| `soc.sv` | Top-level system: address decode, ROM, RAM, UART, processor |
| `processor.sv` | 6-stage FSM CPU core |
| `decoder.sv` | Instruction decoder - opcodes, register addresses, immediates |
| `alu.sv` | ALU - arithmetic, logic, shifts, branch condition flags |
| `load_helper.sv` | Load data alignment and sign extension |
| `store_helper.sv` | Store data replication and byte write mask |
| `bram_sdp.sv` | Simple dual-port block RAM with byte write mask |
| `uart.sv` | UART top-level |
| `baudrate.sv` | Clock enable generator for TX and RX baud rates |
| `transmitter.sv` | UART TX state machine |
| `receiver.sv` | UART RX state machine |
| `fifo.sv` | Synchronous FIFO, circular buffer |
| `firmware_tb.sv` | Firmware simulation testbench |
| `instructions_tb.sv` | Automated ISA test suite |
| `memory.mem` | ISA test program |
| `pinmap.pcf` | FPGA pin constraints |
| `Makefile` | Build system |
| `sw/` | C firmware (see `sw/README.md`) |