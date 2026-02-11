`default_nettype none

module decoder (
    input logic [31:0] instr,

    // Instruction type outputs
    output logic isALUreg,
    output logic isALUimm,
    output logic isLoad,
    output logic isStore,
    output logic isLUI,
    output logic isAUIPC,
    output logic isJAL,
    output logic isJALR,
    output logic isSYSTEM,
    output logic isBranch,

    // Register addresses
    output logic [4:0] rd, 
    output logic [4:0] rs1, 
    output logic [4:0] rs2, 

    // Function codes
    output logic [2:0] funct3,
    output logic [6:0] funct7,

    // Immediates
    output logic [31:0] Iimm,
    output logic [31:0] Simm,
    output logic [31:0] Bimm,
    output logic [31:0] Uimm,
    output logic [31:0] Jimm
);
    // Decode instruction type
    assign isALUreg = (instr[6:0] == 7'b0110011);  // rd <- rs1 OP rs2
    assign isALUimm = (instr[6:0] == 7'b0010011);  // rd <- rs1 OP Iimm
    assign isLoad   = (instr[6:0] == 7'b0000011);  // rd <- mem[rs1 + Iimm]
    assign isStore  = (instr[6:0] == 7'b0100011);  // mem[rs1 + Simm] <- rs2
    assign isLUI    = (instr[6:0] == 7'b0110111);  // rd <- Uimm
    assign isAUIPC  = (instr[6:0] == 7'b0010111);  // rd <- PC + Uimm 
    assign isJAL    = (instr[6:0] == 7'b1101111);  // rd <- PC+4; PC <- rs1 + Jimm
    assign isJALR   = (instr[6:0] == 7'b1100111);  // rd <- PC+4; PC <- Iimm
    assign isSYSTEM = (instr[6:0] == 7'b1110011);  // special
    assign isBranch = (instr[6:0] == 7'b1100011);  // if (rs1 OP rs2) PC <- PC + Bimm

    // Decode register addresses
    assign [4:0] rd = instr[11:7];
    assign [4:0] rs1 = instr[19:15];
    assign [4:0] rs2 = instr[24:20];

    // Decode function codes
    assign [2:0] funct3 = instr[14:12];
    assign [6:0] funct7 = instr[31:25];

    // Decode immediate values based on instruction type
    assign [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
    assign [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    assign [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    assign [31:0] Uimm = {instr[31], instr[30:12], {12{1'b0}}};
    assign [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};
endmodule

