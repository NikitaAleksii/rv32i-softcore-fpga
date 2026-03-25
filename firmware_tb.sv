`default_nettype none
`timescale 1ns / 1ps

module firmware_tb();
    logic clock = 0;
    logic reset;

    always #10 clock = ~clock;  // 50MHz

    soc #(
        .MEM_INIT("firmware.mem"),
        .ROM_DEPTH(8192),
        .RAM_DEPTH(8192),
        .BAUD_RATE(115_200),
        .CLOCK_RATE(50_000_000)
    ) soc_inst (
        .clock,
        .reset,
        .uart_rx(1'b1),
        .uart_tx()
    );

    // Intercept UART TX writes before serialization
    always @(posedge clock) begin
        if (soc_inst.uart_tx_enable)
            $write("%c", soc_inst.mem_write_data[7:0]);
    end

    initial begin
        reset = 1;
        repeat(4) @(posedge clock);
        reset = 0;
        
        #10_000_000;  // 10ms sim time is plenty
        $finish;
    end

endmodule