module store_helper (
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic [31:0] Simm,
    input logic [2:0] funct3,

    output logic [31:0] store_data,
    output logic [31:0] store_addr,
    output logic [3:0] store_mask
);
    assign store_addr = rs1_data + Simm;

    logic [15:0] store_halfword;
    logic [7:0] store_byte;

    assign store_halfword = rs2_data[15:0];
    assign store_byte = rs2_data[7:0];

    // Use mask to store particular bits
    logic [3:0] halfword_mask;
    logic [3:0] byte_mask;

    assign halfword_mask = store_addr[1] ? 4'b1100 : 4'b0011;
    assign byte_mask = (store_addr[1:0] == 2'b00 ? 4'b0001 : (store_addr[1:0] == 2'b01 ? 4'b0010 : (store_addr[1:0] == 2'b10 ? 4'b0100 : 4'b1000)));

    always_comb begin
        case(funct3)
            3'b000 : begin 
                store_data = {store_byte, store_byte, store_byte, store_byte}; // SB
                store_mask = byte_mask;
            end
            3'b001 : begin
                store_data = {store_halfword, store_halfword}; // SH
                store_mask = halfword_mask;
            end
            3'b010 : begin
                store_data = rs2_data; // SW
                store_mask = 4'b1111;
            end
            default: begin
                store_data = 32'b0;
                store_mask = 4'b0000;
            end
        endcase
    end
endmodule