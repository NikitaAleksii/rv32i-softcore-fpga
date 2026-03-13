module baudrate #(
    parameter BAUD_RATE = 115_200,
    parameter CLOCK_RATE = 50_000_000
) (
    input logic clock,    
    output logic Rx_clock_enable,   // Enable signal for rx clock
    output logic Tx_clock_enable    // Enable signal for tx clock
);
    // Calculate the number of clock cycles per baud rate
    localparam Rx_accumulator_max = CLOCK_RATE / (BAUD_RATE * 16);
    localparam Tx_accumulator_max = CLOCK_RATE / BAUD_RATE;
    localparam Rx_accumulator_width = $clog2(Rx_accumulator_max);
    localparam Tx_accumulator_width = $clog2(Tx_accumulator_max);

    // Initialize receiver and trasmitter accumulators
    logic [Rx_accumulator_width - 1:0] Rx_accumulator = 0;
    logic [Tx_accumulator_width - 1:0] Tx_accumulator = 0;

    // Enable flag for Rx and Tx
    assign Rx_clock_enable = (Rx_accumulator == 0);
    assign Tx_clock_enable = (Tx_accumulator == 0);

    // Generate baud rate for Rx
    always @(posedge clock) begin
        if (Rx_accumulator == Rx_accumulator_max - 1)
            Rx_accumulator <= 0;
        else
            Rx_accumulator <= Rx_accumulator + 1;
    end

    // Generate baud rate for Tx
    always @(posedge clock) begin
        if (Tx_accumulator == Tx_accumulator_max - 1)
            Tx_accumulator <= 0;
        else
            Tx_accumulator <= Tx_accumulator + 1; 
    end
endmodule