`default_nettype none

module decoder (
    input logic clock,
    input logic reset,
    input logic [31:0] instr
);
    logic isALUreg = (instr[6:0] == 7'b0110011);  // rd <- rs1 OP rs2
    logic isALUimm = (instr[6:0] == 7'b0010011);  // rd <- rs1 OP Iimm
    logic isLoad   = (instr[6:0] == 7'b0000011);  // rd <- mem[rs1 + Iimm]
    logic isStore  = (instr[6:0] == 7'b0100011);  // mem[rs1 + Simm] <- rs2
    logic isLUI    = (instr[6:0] == 7'b0110111);  // rd <- Uimm
    logic isAUIPC  = (instr[6:0] == 7'b0010111);  // rd <- PC + Uimm 
    logic isJAL    = (instr[6:0] == 7'b1101111);  // rd <- PC+4; PC <- rs1 + Jimm
    logic isJALR   = (instr[6:0] == 7'b1100111);  // rd <- PC+4; PC <- Iimm
    logic isSYSTEM = (instr[6:0] == 7'b1110011);  // special
    logic isBranch = (instr[6:0] == 7'b1100011);  // if (rs1 OP rs2) PC <- PC + Bimm

    logic [4:0] rd = instr[11:7];
    logic [4:0] rs1 = instr[19:15];
    logic [4:0] rs2 = instr[24:20];

    logic [2:0] funct3 = instr[14:12];
    logic [6:0] funct7 = instr[31:25];

    logic [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
    logic [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    logic [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    logic [31:0] Uimm = {instr[31], instr[30:12], {12{1'b0}}};
    logic [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};

endmodule

