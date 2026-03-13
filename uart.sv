module uart #(
    parameter BAUD_RATE = 115_200,
    parameter CLOCK_RATE = 50_000_000
) (
    input logic clock,
    
    input logic Rx,
    input logic Rx_enable,
    input logic ready_clear,
    output logic Rx_ready,
    output logic [7:0] data_output,

    input logic [7:0] data_input,
    input logic Tx_enable,
    output logic Tx,
    output logic Tx_busy
);
    
    logic Rx_clock_enable;
    logic Tx_clock_enable;

    baudrate #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) baudrate_inst (
        .clock(clock),
        .Rx_clock_enable(Rx_clock_enable),
        .Tx_clock_enable(Tx_clock_enable)
    );

    transmitter transmitter_inst(
        .data_input(data_input),
        .clock(clock),
        .Tx_clock_enable(Tx_clock_enable),
        .Tx_enable(Tx_enable),
        .Tx(Tx),
        .Tx_busy(Tx_busy)
    );

    receiver receiver_inst(
        .Rx(Rx),
        .Rx_enable(Rx_enable),
        .ready_clear(ready_clear),
        .clock(clock),
        .Rx_clock_enable(Rx_clock_enable),
        .ready(Rx_ready),
        .data_output(data_output)
    );

endmodule