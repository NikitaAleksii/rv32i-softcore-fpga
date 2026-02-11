`default_nettype none

module processor #(
    parameter INIT = ""
) (
    input logic clock,
    input logic reset
);
    logic [6:0] counter;

    logic [31:0] data_out;
    logic read_enable = 0;

    bram_sdp #(
    .WIDTH(32), 
    .DEPTH(128),
    .INIT("memory.mem")
    ) bram_inst (
    .clock_read(clock),
    .read_enable(read_enable),
    .addr_read(counter),
    .data_out(data_out)
    );

    always_ff @(posedge clock, posedge reset) 
    begin
        if (reset)
        begin
            read_enable <= 1;
            counter <= 0;
        end
        else 
        begin
            counter <= counter + 1;

            if (counter == 73)
                counter <= 0;

            $display("Instruction opcode %b", data_out[6:0]); // print the opcode of the instuction
        end
    end 


    always_ff @(posedge clock)
    begin
            case (1'b1)
                (data_out[6:0] == 7'b0110011) : $display("PC=%d ALUreg", counter);
                (data_out[6:0] == 7'b0010011) : $display("PC=%d ALUimm", counter);
                (data_out[6:0] == 7'b1100011) : $display("PC=%d BRANCH", counter);
                (data_out[6:0] == 7'b1101111) : $display("PC=%d JAL", counter);
                (data_out[6:0] == 7'b1100111) : $display("PC=%d JALR", counter);
                (data_out[6:0] == 7'b0010111) : $display("PC=%d AUIPC", counter);
                (data_out[6:0] == 7'b0110111) : $display("PC=%d LUI", counter);
                (data_out[6:0] == 7'b0000011) : $display("PC=%d LOAD", counter);
                (data_out[6:0] == 7'b0100011) : $display("PC=%d STORE", counter);
                (data_out[6:0] == 7'b1110011) : $display("PC=%d SYSTEM", counter);
            endcase
    end


endmodule
