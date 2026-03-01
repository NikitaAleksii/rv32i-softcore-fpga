module load_helper (
    input logic [31:0] rs1_data,
    input logic [31:0] Iimm,
    input logic [2:0] funct3,
    input logic [31:0] mem_data,

    output logic [31:0] load_data,
    output logic [31:0] load_addr
);
    assign load_addr = rs1_data + Iimm;

    logic [15:0] load_halfword;
    logic [7:0] load_byte;

    assign load_halfword = load_addr[1] ? mem_data[31:16] : mem_data[15:0];
    assign load_byte = (load_addr[1:0] == 2'b00 ? mem_data[7:0] : (load_addr[1:0] == 2'b01 ? mem_data[15:8] : (load_addr[1:0] == 2'b10 ? mem_data[23:16] : mem_data[31:24])));

    logic halfword_sign;
    logic byte_sign;

    assign halfword_sign = load_halfword[15];
    assign byte_sign = load_byte[7];

    always_comb begin
        case (funct3) 
            3'b000 : load_data = {{24{byte_sign}}, load_byte}; // LB (sign-extend)
            3'b001 : load_data = {{16{halfword_sign}}, load_halfword}; // LH (sign-extend)
            3'b010 : load_data = mem_data; // LW
            3'b100 : load_data = {24'b0, load_byte}; // LBU (zero-extend)
            3'b101 : load_data = {16'b0, load_halfword}; // LHU (zero-extend)
            default : load_data = 32'b0;
        endcase
    end
endmodule