module transmitter (
    input logic [7:0] data_input,
    input logic clock,
    input logic Tx_clock_enable,
    input logic Tx_enable,
    output logic Tx,
    output logic Tx_busy
);
    
    initial begin
        Tx <= 1'b1;
    end

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
        case (state)
            Tx_IDLE: begin
                if (Tx_enable) begin
                    state <= Tx_START;
                    bit_position <= 3'b0;
                    temporary_byte <= data_input;
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