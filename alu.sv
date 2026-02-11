module alu #(
    parameter WIDTH = 32
) (
    input logic [WIDTH-1:0] rs1_data,
    input logic [WIDTH-1:0] rs2_data,
    input logic [WIDTH-1:0] Iimm,
    
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic isALUreg,

    output logic [WIDTH-1:0] aluOut
);

    logic [4:0] shamt;
    logic [WIDTH-1:0] aluIn1;
    logic [WIDTH-1:0] aluIn2;
    
    // Select shift amount
    assign shamt  = isALUreg ? rs2_data[4:0] : Iimm[4:0];

    // Select ALU inputs
    assign aluIn1 = rs1_data;
    assign aluIn2 = isALUreg ? rs2_data : Iimm;
    
    always_comb begin
        case(funct3)
            3'b000 : aluOut = (isALUreg & funct7[5]) ? (aluIn1-aluIn2) : (aluIn1+aluIn2); // ADD/SUB
            3'b001 : aluOut = aluIn1 << shamt; // SLL
            3'b010 : aluOut = {{(WIDTH-1){1'b0}}, $signed(aluIn1) < $signed(aluIn2)}; // SLT
            3'b011 : aluOut = {{(WIDTH-1){1'b0}}, aluIn1 < aluIn2}; // SLTU
            3'b100 : aluOut = (aluIn1 ^ aluIn2); // XOR
            3'b101 : aluOut = funct7[5]? ($signed(aluIn1) >>> shamt) : (aluIn1 >> shamt); // SRL
            3'b110 : aluOut = (aluIn1 | aluIn2); // OR
            3'b111 : aluOut = (aluIn1 & aluIn2); // AND
            default: aluOut = {WIDTH{1'b0}};
        endcase
    end
endmodule