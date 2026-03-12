`default_nettype none
`timescale 1ns / 1ps

module soc #(
    parameter MEM_DEPTH=4096,
    parameter MEM_INIT="memory.mem"
) (
    input logic clock,
    input logic reset
);
    // Set memory parameters
    localparam MEM_ADDR_WIDTH=$clog2(MEM_DEPTH);

    // Memory Registers
    logic mem_write_enable;
    logic mem_read_enable;
    logic [3:0] write_mask;
    logic [31:0] mem_write_data;
    logic [31:0] mem_read_addr;
    logic [31:0] mem_write_addr;
    logic [31:0] mem_data;

    // Bram memory
    bram_sdp #(
        .WIDTH(32), 
        .DEPTH(MEM_DEPTH),
        .INIT(MEM_INIT)
    ) bram_inst (
        .clock_write(clock),
        .clock_read(clock),
        .write_enable(mem_write_enable),
        .read_enable(mem_read_enable),
        .mem_mask_write(write_mask),
        .addr_write(mem_write_addr[MEM_ADDR_WIDTH+1:2]),   
        .addr_read(mem_read_addr[MEM_ADDR_WIDTH+1:2]),      
        .data_in(mem_write_data),
        .data_out(mem_data)              // Use memory for both instuctions and data
    );

    // Processor instantiation
    processor #(
        .MEM_INIT(MEM_INIT),
        .MEM_DEPTH(MEM_DEPTH)
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