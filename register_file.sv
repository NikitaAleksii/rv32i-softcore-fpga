module register_file #(
    parameter WIDTH = 32,
    parameter DEPTH = 32
) (
    input logic clock,
    input logic reset,

    // Read Port
    input logic [4:0] rs1_addr,
    output logic [WIDTH-1:0] rs1_data, 

    input logic [4:0] rs2_addr,
    output logic [WIDTH-1:0] rs2_data,

    // Write Port
    input logic write_en,
    input logic [WIDTH-1:0] write_data,
    input logic [4:0] rd_addr
);
    // Internal Storage; x0 is special
    logic [WIDTH-1:0] registers [1:DEPTH-1]; 

    // Read logic
    assign rs1_data = (rs1_addr == 5'b0) ? 0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'b0) ? 0 : registers[rs2_addr];

    // Write logic
    always_ff @(posedge clock)
    begin
        if (!reset)
            registers <= '{default: '0};
        else if (write_en && rd_addr != 5'b0)
            registers[rd_addr] <= write_data;
    end
endmodule