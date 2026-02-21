module alu #(
    parameter WIDTH = 32
) (
    input logic isBranch,

    input logic [WIDTH-1:0] rs1_data,
    input logic [WIDTH-1:0] rs2_data,
    input logic [WIDTH-1:0] Iimm,
    
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic isALUreg,

    output logic [WIDTH-1:0] aluOut,

    output logic EQ,
    output logic LT,
    output logic LTU
);

    logic [4:0] shamt;
    logic [WIDTH-1:0] aluIn1;
    logic [WIDTH-1:0] aluIn2;
    logic [32:0] aluMinus;
    
    // Select shift amount
    assign shamt  = isALUreg ? rs2_data[4:0] : Iimm[4:0];

    // Select ALU inputs
    assign aluIn1 = rs1_data;
    assign aluIn2 = (isALUreg || isBranch) ? rs2_data : Iimm;

    // 33-bit subtraction with MSB as overflow detection
    assign aluMinus = {1'b0,aluIn1} - {1'b0,aluIn2};
    
    assign EQ = (aluMinus[31:0] == 0); // Equal
    assign LT = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32]; // Less than
    assign LTU = aluMinus[32]; // Less than unsigned

    always_comb begin
        case(funct3)
            3'b000 : aluOut = (isALUreg & funct7[5]) ? (aluIn1-aluIn2) : (aluIn1+aluIn2); // ADD/SUB
            3'b001 : aluOut = aluIn1 << shamt; // SLL
            3'b010 : aluOut = {31'b0, LT}; // SLT
            3'b011 : aluOut = {31'b0, LTU}; // SLTU
            3'b100 : aluOut = (aluIn1 ^ aluIn2); // XOR
            3'b101 : aluOut = funct7[5]? ($signed(aluIn1) >>> shamt) : (aluIn1 >> shamt); // SRL
            3'b110 : aluOut = (aluIn1 | aluIn2); // OR
            3'b111 : aluOut = (aluIn1 & aluIn2); // AND
            default: aluOut = {WIDTH{1'b0}};
        endcase
    end
endmodule