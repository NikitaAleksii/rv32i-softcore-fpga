`default_nettype none

module uart #(
    parameter BAUD_RATE = 115_200,
    parameter CLOCK_RATE = 50_000_000,
    parameter FIFO_DEPTH = 16
) (
    input logic clock,
    
    // RX
    input logic rx_read_enable,
    output logic rx_full,
    output logic rx_empty,
    output logic [7:0] rx_data,

    // TX
    input logic tx_write_enable,
    input logic [7:0] tx_data,
    output logic tx_empty,
    output logic tx_full,
    output logic tx_busy,

    // UART
    input logic Rx,
    input logic Rx_enable,
    output logic Tx
);
    logic Rx_clock_enable;
    logic Tx_clock_enable;

    // FIFO wires
    logic tx_fifo_read_enable;
    logic [7:0] tx_fifo_data;

    logic rx_fifo_write_enable;
    logic [7:0] rx_fifo_data;

    baudrate #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) baudrate_inst (
        .clock(clock),
        .Rx_clock_enable(Rx_clock_enable),
        .Tx_clock_enable(Tx_clock_enable)
    );

    fifo #(
        .DEPTH(FIFO_DEPTH),
        .WIDTH(8)
    ) tx_fifo_inst (
        .clock(clock),
        .reset(1'b0),
        .write_enable(tx_write_enable),
        .data_in(tx_data),
        .read_enable(tx_fifo_read_enable),
        .data_out(tx_fifo_data),
        .full(tx_full),
        .empty(tx_empty)
    );

    transmitter transmitter_inst (
        .clock(clock),
        .Tx_clock_enable(Tx_clock_enable),
        .fifo_empty(tx_empty),
        .fifo_data(tx_fifo_data),
        .fifo_read_enable(tx_fifo_read_enable),
        .Tx(Tx),
        .Tx_busy(tx_busy)
    );

   fifo #(
        .DEPTH(FIFO_DEPTH),
        .WIDTH(8)
    ) rx_fifo_inst (
        .clock(clock),
        .reset(1'b0),
        .write_enable(rx_fifo_write_enable),
        .data_in(rx_fifo_data),
        .read_enable(rx_read_enable),
        .data_out(rx_data),
        .full(rx_full),
        .empty(rx_empty)
    );

    receiver receiver_inst (
        .clock(clock),
        .Rx(Rx),
        .Rx_enable(Rx_enable),
        .Rx_clock_enable(Rx_clock_enable),
        .fifo_full(rx_full),
        .fifo_write_enable(rx_fifo_write_enable),
        .fifo_data(rx_fifo_data)
    );

endmodule