module conflict_checker (
    input logic [31:0] R_instruction,
    input logic [31:0] W_instruction,

    output logic conflict
);
    logic [4:0] r_rs1, r_rs2;
    logic [6:0] w_opcode;
    logic [4:0] w_rd;

    assign r_rs1 = R_instruction[19:15];
    assign r_rs2 = R_instruction[24:20];
    assign w_opcode = W_instruction[6:0];
    assign w_rd = W_instruction[11:7];

    // Check it W is writing to a register
    logic writeReg;
    assign writeReg = (w_opcode == 7'b0000011) // LOAD
                     |(w_opcode == 7'b0110011) // ALUreg
                     |(w_opcode == 7'b0010011) // ALUimm
                     |(w_opcode == 7'b0110111) // LUI
                     |(w_opcode == 7'b0010111) // AUIPC
                     |(w_opcode == 7'b1101111) // JAL
                     |(w_opcode == 7'b1100111); // JALR

    // Conflict if W writes a result that R needs,
    // and the destination is not x0
    assign conflict = writeReg && (w_rd != 5'b0) && (w_rd == r_rs1 || w_rd == r_rs2);
endmodule