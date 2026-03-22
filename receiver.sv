`default_nettype none

module receiver (
    input logic clock,

    // RX FIFO
    input logic fifo_full,
    output logic fifo_write_enable,
    output logic [7:0] fifo_data,

    // UART Line
    input logic Rx,              // Serial input data
    input logic Rx_enable,
    input logic Rx_clock_enable
);
    // Initialize states
    typedef enum {
        Rx_START,
        Rx_DATA,
        Rx_STOP
    } state_t;

    // Initialize internal registers
    state_t state = Rx_START;
    logic [3:0] counter = 4'b0;
    logic [3:0] bit_position = 4'b0;
    logic [7:0] temporary_byte = 8'b0;

    always @(posedge clock) begin
        fifo_write_enable <= 1'b0;

        if (Rx_clock_enable && Rx_enable) begin
            case(state)
                Rx_START: begin
                    if (!Rx)
                        counter <= counter + 1;
                    else
                        counter <= 4'b0;
                    if (counter == 15) begin
                        counter <= 4'b0;
                        bit_position <= 4'b0;
                        temporary_byte <= 8'b0; 
                        state <= Rx_DATA;
                    end
                end
                Rx_DATA: begin
                    counter <= counter + 1;
                    if (counter == 8) begin
                        temporary_byte[bit_position[2:0]] <= Rx;
                        bit_position <= bit_position + 1;
                    end
                    if (counter == 15 && bit_position == 8) begin
                        state <= Rx_STOP;
                    end
                end
                Rx_STOP: begin
                    if (counter == 15 || (counter >= 8 && !Rx)) begin
                        if (!fifo_full) begin
                            fifo_data <= temporary_byte;
                            fifo_write_enable <= 1'b1;
                        end
                        state <= Rx_START;
                        counter <= 0;
                    end else 
                        counter <= counter + 1;
                end
                default: 
                        state <= Rx_START;
            endcase
        end
    end
    
endmodule