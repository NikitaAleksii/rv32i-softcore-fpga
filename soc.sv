`default_nettype none
`timescale 1ns / 1ps

// --------------------------------------------------------------------- 
// Memory Map
// 
//  0x0000_0000 – 0x0000_7FFF    ROM  (32 KB, 8192 words)   read-only
//                               .text, .rodata live here
//  0x0000_8000 – 0x0000_FFFF   RAM  (32 KB, 8192 words)   read/write
//                               .data, .bss, stack live here
//
//  0x1000_0000                  UART TX  (write byte)
//  0x1000_0004                  UART status  bit[0]=Tx_busy  bit[1]=Rx_ready
//  0x1000_0008                  UART RX  (read byte, clears Rx_ready)
// ---------------------------------------------------------------------

module soc #(
    parameter MEM_INIT="memory.mem",
    parameter ROM_DEPTH=8192,
    parameter RAM_DEPTH=8192,
    parameter BAUD_RATE = 115_200,
    parameter CLOCK_RATE = 50_000_000
) (
    input logic clock,
    input logic reset,

    input logic uart_rx,
    output logic uart_tx
);
    // CPU bus
    logic mem_write_enable;
    logic mem_read_enable;
    logic [3:0] write_mask;
    logic [31:0] mem_write_data;
    logic [31:0] mem_read_addr;
    logic [31:0] mem_write_addr;
    logic [31:0] mem_data;

    // ---------------------------------------------------------------------
    // Address Decode
    // 
    // Read Adress bit[15]:
    //    0  ->  ROM   0x0000_0000 – 0x0000_1FFF
    //    1  ->  RAM   0x0000_2000 – 0x0000_3FFF
    //
    //  Write address bits[31:16] == 0x1000  ->  UART
    //  Write address bit[13] == 1           ->  RAM
    // ---------------------------------------------------------------------

    wire sel_rom_rd = mem_read_enable && (mem_read_addr[31:16] == 16'b0)
                                       && (mem_read_addr[15] == 1'b0);

    wire sel_ram_rd = mem_read_enable && (mem_read_addr[31:16] == 16'b0)
                                       && (mem_read_addr[15] == 1'b1);

    wire sel_ram_wr = mem_write_enable && (mem_write_addr[31:16] == 16'b0)
                                       && (mem_write_addr[15] == 1'b1);

    wire sel_uart_rd = mem_read_enable && (mem_read_addr[31:16] == 16'h1000);
    wire sel_uart_wr = mem_write_enable && (mem_write_addr[31:16] == 16'h1000);

    //  ---------------------------------------------------------------------
    //  ROM 8KB, read-only, initialized from firmware.mem at synthesis
    //  ---------------------------------------------------------------------
    localparam ROM_ADDR_WIDTH = $clog2(ROM_DEPTH);

    logic [31:0] rom_out;

    bram_sdp #(
        .WIDTH(32), 
        .DEPTH(ROM_DEPTH),
        .INIT(MEM_INIT)
    ) rom_inst (
        .clock_write(clock),
        .clock_read(clock),
        .write_enable(1'b0),
        .read_enable(sel_rom_rd),
        .mem_mask_write(4'b0),
        .addr_write({ROM_ADDR_WIDTH{1'b0}}),   
        .addr_read(mem_read_addr[ROM_ADDR_WIDTH+1:2]),      
        .data_in(32'b0),
        .data_out(rom_out)          
    );

    //  ---------------------------------------------------------------------
    //  RAM 8KB, read/write
    //  ---------------------------------------------------------------------
    localparam RAM_ADDR_WIDTH = $clog2(RAM_DEPTH);

    logic [31:0] ram_out;

    bram_sdp #(
        .WIDTH(32), 
        .DEPTH(RAM_DEPTH),
        .INIT("")
    ) ram_inst (
        .clock_write(clock),
        .clock_read(clock),
        .write_enable(sel_ram_wr),
        .read_enable(sel_ram_rd),
        .mem_mask_write(write_mask),
        .addr_write(mem_write_addr[RAM_ADDR_WIDTH+1:2]),   
        .addr_read(mem_read_addr[RAM_ADDR_WIDTH+1:2]),      
        .data_in(mem_write_data),
        .data_out(ram_out)          
    );

    //  ---------------------------------------------------------------------
    //  UART
    //  ---------------------------------------------------------------------

    logic uart_tx_busy;
    logic uart_rx_ready;
    logic [7:0] uart_rx_data;

    logic uart_rx_enable = sel_uart_rd && (mem_read_addr == 32'h1000_0008);
    logic uart_tx_enable = sel_uart_wr && (mem_write_addr == 32'h1000_0000);

    uart #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) uart_inst (
        .clock(clock),
        .Rx(uart_rx),
        .Rx_enable(1'b1),
        .ready_clear(uart_rx_enable),
        .Rx_ready(uart_rx_ready),
        .data_output(uart_rx_data),
        .data_input(mem_write_data[7:0]),
        .Tx_enable(uart_tx_enable),
        .Tx(uart_tx),
        .Tx_busy(uart_tx_busy)
    );

    // ---------------------------------------------------------------------
    // Read-data mux
    //
    // ROM and RAM are synchronous. UART registers are combinational.
    // Use a registered copy of mem_read_addr so all paths arrive together.
    // ---------------------------------------------------------------------

    logic [31:0] mem_read_addr_r;

    always_ff @(posedge clock)
        mem_read_addr_r <= mem_read_addr;

    always_comb begin
        case(1'b1)
            (mem_read_addr_r[31:16] == 16'h1000 &&
             mem_read_addr_r[3:0] == 4'h4)      : mem_data = {30'b0, uart_rx_ready, uart_tx_busy};
            (mem_read_addr_r[31:16] == 16'h1000 &&
             mem_read_addr_r[3:0] == 4'h8)      : mem_data = {24'b0, uart_rx_data};
            (mem_read_addr_r[15] == 1'b1)       : mem_data = ram_out;
            default                             : mem_data = rom_out;

        endcase
    end

    //  ---------------------------------------------------------------------
    //  Processor
    //  ---------------------------------------------------------------------
    processor #(
        .MEM_INIT(MEM_INIT),
        .MEM_DEPTH(ROM_DEPTH)
    ) processor_inst(
        .clock,
        .reset,
        .mem_data,
        .mem_write_enable,
        .mem_read_enable,
        .write_mask,
        .mem_write_data,
        .mem_write_addr,
        .mem_read_addr
    );
    
endmodule