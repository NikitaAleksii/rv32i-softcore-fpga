`default_nettype none
`timescale 1ns / 1ps

module firmware_tb();
    parameter BAUD_RATE  = 115_200;
    parameter CLOCK_RATE = 50_000_000;
    parameter PTY_PATH   = "/tmp/vserial";

    logic clock = 0;
    logic reset;
    logic uart_rx = 1'b1;
    logic uart_tx;

    always #10 clock = ~clock;  // 50 MHz

    soc #(
        .MEM_INIT("firmware.mem"),
        .ROM_DEPTH(8192),
        .RAM_DEPTH(8192),
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) soc_inst (
        .clock,
        .reset,
        .uart_rx,
        .uart_tx
    );

    localparam real BIT_PERIOD = 1_000_000_000 / BAUD_RATE;  // ~8680 ns

    // TX path — simulation -> picocom
    integer sp_fd = 0;

    initial begin
        string path;
        path = {PTY_PATH, "_sp"};
        #2000;
        sp_fd = $fopen(path, "w");
        if (sp_fd == 0) $display("[ERROR] Cannot open %s", path);
        else            $display("[TX] Bridge file opened: %s", path);
    end

    always @(posedge clock) begin
        if (soc_inst.uart_tx_enable && sp_fd != 0) begin    // sp_fd != 0 guards against writing before the file is open
            $fwrite(sp_fd, "%c", soc_inst.mem_write_data[7:0]);
            $fflush(sp_fd);
        end
    end

    // This task synthesizes a real UART waveform on the uart_rx pin
    task automatic send_uart_rx(input logic [7:0] data);
        uart_rx = 1'b0;                    // start bit
        #(BIT_PERIOD);
        for (int i = 0; i < 8; i++) begin
            uart_rx = data[i];
            #(BIT_PERIOD);
        end
        uart_rx = 1'b1;                    // stop bit
        #(BIT_PERIOD);
    endtask

    // Continuously polls PS_FILE for new bytes from picocom and sends each one to the SoC as a real UART waveform
    initial begin
        integer ps_fd, pos, ch;
        string path;
        path = {PTY_PATH, "_ps"};
        pos = 0;
        #2000;
        $display("[RX] Polling: %s", path);
        forever begin
            #(BIT_PERIOD * 10);
            // RX opens and closes every iteration ensuring the latest contents are visible 
            ps_fd = $fopen(path, "r");
            if (ps_fd != 0) begin
                if (pos > 0) void'($fseek(ps_fd, pos, 0));
                ch = $fgetc(ps_fd);
                while (ch >= 0 && ch <= 255) begin
                    pos++;
                    $display("[RX] sending 0x%02x (%c)", ch, ch);
                    send_uart_rx(ch[7:0]);
                    ch = $fgetc(ps_fd);
                end
                $fclose(ps_fd);
            end
        end
    end

    // Reset
    initial begin
        reset = 1;
        repeat(4) @(posedge clock);
        reset = 0;
        $display("Reset done.");
    end

endmodule