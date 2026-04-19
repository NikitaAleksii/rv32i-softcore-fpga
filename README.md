# rv32i-softcore-fpga

RV32I RISC-V softcore processor implemented in SystemVerilog.

## Architecture

The SoC is composed of a processor core, block RAM for ROM and RAM, and a UART peripheral.

The **processor** (`processor4.sv`) is a 5-stage in-order pipeline: `FETCH → DECODE → EXECUTE → MEMORY → WRITE_BACK`. All five stages operate concurrently each clock cycle. A simple 3-state FSM (`HALT → INIT → RUN`) controls startup and halting; once in `RUN` all pipeline stages advance together.

An 8-entry **prefetch buffer** decouples instruction fetch from decode. Fetch speculatively advances the PC and writes fetched instructions into the circular buffer; Decode consumes from the other end. This absorbs one-cycle stalls without stalling the fetch unit.

**Hazard handling:**

- *Data hazards (RAW)*: a `forwarder` module bypasses results directly from the Execute, Memory, and Write-Back stages back to the Execute stage inputs, eliminating most stall cycles. A `conflict_checker` module handles the remaining cases (e.g. load-use hazards) where forwarding is insufficient, stalling Decode until the value is available. With forwarding in place the measured CPI is **1.7**.
- *Control hazards*: when a branch is taken or a JAL/JALR resolves in Execute, the prefetch buffer is flushed and the Decode and Execute pipeline registers are replaced with NOPs, redirecting fetch to the correct target.
- *Structural hazards*: Fetch and the Execute/Memory data path share the same memory bus. Stores take priority; pending data reads preempt instruction fetches; fetch is suppressed when the bus is busy.

The decoder extracts opcodes, register addresses, and all immediate formats from the 32-bit instruction word. The ALU handles arithmetic, logic, shifts, and produces comparison flags for branches. Load and store helpers handle sub-word access — byte and halfword extraction, sign extension, and write mask generation.

CSR performance counters (`cycles`, `instructions_retired`) are supported via `CSRRS` for benchmarking.

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
| `processor.sv` | Original 6-stage FSM CPU core (superseded) |
| `processor2.sv` | 6-stage FSM with pipeline registers added (intermediate iteration) |
| `processor3.sv` | 5-stage pipelined CPU core with prefetch buffer and hazard handling (superseded) |
| `processor4.sv` | 5-stage pipelined CPU core with forwarding unit — measured CPI 1.7 |
| `forwarder.sv` | Data forwarding unit — bypasses EX/MEM/WB results to EX stage inputs |
| `conflict_checker.sv` | RAW data hazard detector — stalls on load-use and unresolvable hazards |
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