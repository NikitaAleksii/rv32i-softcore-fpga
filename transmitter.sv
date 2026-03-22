`default_nettype none

module transmitter (
    input logic clock,
    input logic Tx_clock_enable,

    // TX FIFO
    input logic [7:0] fifo_data,
    input logic fifo_empty,
    output logic fifo_read_enable,

    // UART line
    output logic Tx,
    output logic Tx_busy
);
    
    initial Tx <= 1'b1;

    typedef enum {
        Tx_IDLE,
        Tx_START,
        Tx_DATA,
        Tx_STOP
    } state_t;

    // Initialize internal registers
    state_t state = Tx_IDLE;
    logic [2:0] bit_position = 3'b0;
    logic [7:0] temporary_byte = 8'b0;

    assign Tx_busy = (state != Tx_IDLE);

    always @(posedge clock) begin
        fifo_read_enable <= 1'b0;

        case (state)
            Tx_IDLE: begin
                if (!fifo_empty) begin
                    fifo_read_enable <= 1'b1;
                    state <= Tx_START;
                    bit_position <= 3'b0;
                    temporary_byte <= fifo_data;
                end
            end
            Tx_START: begin
                if (Tx_clock_enable) begin
                    Tx <= 1'b0;
                    state <= Tx_DATA;        
                end
            end
            Tx_DATA: begin
                if (Tx_clock_enable) begin
                    Tx <= temporary_byte[bit_position];
                    bit_position <= bit_position + 1;
                    if (bit_position == 7)
                        state <= Tx_STOP;     
                end
            end
            Tx_STOP: begin
                if (Tx_clock_enable) begin
                    state <= Tx_IDLE;
                    Tx <= 1'b1;
                end
            end
            default: begin
                state <= Tx_IDLE;
                Tx <= 1'b1;
            end
        endcase
    end

endmodule