`default_nettype none
`timescale 1ns / 1ps

// This code is based on Project F's line drawing tutorial (projectF.io)
// with modifications and cleanup

module bram_sdp #(
    parameter WIDTH=8, 
    parameter DEPTH=256, 
    parameter INIT=""
    ) (
    input logic clock_write,
    input logic clock_read,

    input logic write_enable,
    input logic read_enable,

    input logic [3:0] mem_mask_write,

    input logic [ADDR_WIDTH-1:0] addr_write,
    input logic [ADDR_WIDTH-1:0] addr_read,

    input logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);

    localparam ADDR_WIDTH=$clog2(DEPTH);

    logic [WIDTH-1:0] memory [DEPTH];

    initial begin
        if (INIT != "") begin
            $display("Load init file '%s' into bram_sdp.", INIT);
            $readmemh(INIT, memory);
        end
    end

    // Port A: Sync Write
    always_ff @(posedge clock_write) begin
        if (write_enable) begin
            if(mem_mask_write[0]) memory[addr_write][ 7:0 ] <= data_in[ 7:0 ];
            if(mem_mask_write[1]) memory[addr_write][15:8 ] <= data_in[15:8 ];
            if(mem_mask_write[2]) memory[addr_write][23:16] <= data_in[23:16];
            if(mem_mask_write[3]) memory[addr_write][31:24] <= data_in[31:24];
        end
    end

    // Port B: Sync Read
    always_ff @(posedge clock_read) begin
        if (read_enable) data_out <= memory[addr_read];
    end
endmodule
