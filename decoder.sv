reg [31:0] instr;

wire isALUreg = (instr[6:0] == 7'b0110011);  // rd <- rs1 OP rs2
wire isALUimm = (instr[6:0] == 7'b0010011);  // rd <- rs1 OP Iimm
wire isLoad   = (instr[6:0] == 7'b0000011);  // rd <- mem[rs1 + Iimm]
wire isStore  = (instr[6:0] == 7'b0100011);  // mem[rs1 + Simm] <- rs2
wire isLUI    = (instr[6:0] == 7'b0110111);  // rd <- Uimm
wire isAUIPC  = (instr[6:0] == 7'b0010111);  // rd <- PC + Uimm 
wire isJal    = (instr[6:0] == 7'b1101111);  // rd <- PC+4; PC <- rs1 + Jimm
wire isJalr   = (instr[6:0] == 7'b1100111);  // rd <- PC+4; PC <- Iimm
wire isSystem = (instr[6:0] == 7'b1110011);  // special
wire isBranch = (instr[6:0] == 7'b1100011);  // if (rs1 OP rs2) PC <- PC + Bimm

wire [4:0] rd = instr[11:7];
wire [4:0] rs1 = instr[19:15];
wire [4:0] rs2 = instr[24:20];

wire [2:0] funct3 = instr[14:12];
wire [6:0] funct7 = instr[31:25];

wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
wire [31:0] Uimm = {instr[31], instr[30:12], {12{1'b0}}};
wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};