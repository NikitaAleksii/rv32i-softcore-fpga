`default_nettype none

module processor #(
    parameter MEM_INIT = "memory.mem",
    parameter MEM_DEPTH = 4096
) (
    input logic clock,
    input logic reset,

    output logic mem_write_enable,
    output logic mem_read_enable,

    output logic [3:0] write_mask,
    output logic [31:0] mem_write_data,
    output logic [31:0] mem_write_addr,

    output logic [31:0] mem_read_addr,
    input logic [31:0] mem_data
);
    // Machine States
    typedef enum { 
        HALT,
        INIT,
        FETCH,
        DECODE,
        EXECUTE,
        MEMORY,
        WRITE_BACK
    } state_t;

    // Current and next states
    state_t state;

    // Program counter
    logic [31:0] PC, next_PC;

    // Instruction
    logic [31:0] instr;

    assign instr = (state == DECODE) ? mem_data : fetched_instr;

    // Handle instructions and target addresses
    logic [31:0] fetched_instr;

    logic [31:0] jump_target;
    logic [31:0] jumpr_target;
    logic [31:0] branch_target;
    
    // Instruction type outputs
    logic isALUreg, isALUimm, isLoad, isStore, isLUI, isAUIPC, isJAL;
    logic isJALR, isSYSTEM, isBranch;
    logic isEBREAK, isECALL; 
    logic isCSR_RS;

    // Register addresses
    logic [4:0] rd, rs1, rs2; 

    // Register data
    logic [31:0] rs1_data, rs2_data;
    assign rs1_data = (rs1 == 5'b0) ? 0 : registers[rs1];
    assign rs2_data = (rs2 == 5'b0) ? 0 : registers[rs2];

    // Additional opcodes
    logic [2:0] funct3;
    logic [6:0] funct7;

    // Immediates 
    logic [31:0] Iimm, Simm, Bimm, Uimm, Jimm;

    // Registers
    logic [31:0] registers [0:31]; 

    logic reg_write_enable;
    logic [31:0] reg_write_data;

    // ALU output
    logic [31:0] aluOut;
    logic EQ; // Equal
    logic LT; // Less than
    logic LTU; // Less than unsigned

    // Decoder 
    decoder decoder_isnt (
        .instr,
        .isALUreg,
        .isALUimm,
        .isLoad,
        .isStore,
        .isLUI,
        .isAUIPC,
        .isJAL,
        .isJALR,
        .isSYSTEM,
        .isBranch,
        .isEBREAK,
        .isECALL,
        .isCSR_RS,
        .rd,
        .rs1,
        .rs2,
        .funct3,
        .funct7,
        .Iimm,
        .Simm,
        .Bimm,
        .Uimm,
        .Jimm
    );

    // ALU instantiation
    alu #(
        .WIDTH(32)
    ) alu_inst (
        .isBranch,
        .rs1_data,
        .rs2_data,
        .Iimm,
        .funct3,
        .funct7,
        .isALUreg,
        .aluOut,
        .EQ,
        .LT,
        .LTU
    );

    // Handle LOAD by computing bytes and halfwords and assigning them to load data output
    logic [31:0] load_data;
    logic [31:0] load_addr;

    load_helper load_helper_inst(
        .rs1_data,
        .Iimm,
        .funct3,
        .mem_data,
        .load_data,
        .load_addr
    );

    // Handle STORE by computing bytes and halfwords and assigning them to store data output
    logic [31:0] store_data;
    logic [31:0] store_addr;
    logic [3:0] store_mask;

    store_helper store_helper_inst(
        .rs1_data,
        .rs2_data,
        .Simm,
        .funct3,
        .store_data,
        .store_addr,
        .store_mask
    );

    // Handle Branches
    logic takeBranch;

    always_comb begin
        case(funct3)
            3'b000 : takeBranch = EQ; // BEQ
            3'b001 : takeBranch = !EQ; // BNE
            3'b100 : takeBranch = LT; // BLT
            3'b101 : takeBranch = !LT; // BGE
            3'b110 : takeBranch = LTU; // BLTU
            3'b111 : takeBranch = !LTU; // BGEU
            default: takeBranch = 1'b0;
        endcase
    end

    // Initialize CSR registers
    logic [63:0] cycles;
    logic [63:0] instructions_retired;

    // Combinatorial logic to get CSR data
    logic [31:0] csr_data;

    always_comb begin
        case(Iimm[11:0])
            12'hC00:
                csr_data = cycles[31:0];
            12'hC80:
                csr_data = cycles[63:32];
            12'hC02:
                csr_data = instructions_retired[31:0];
            12'hC82:
                csr_data = instructions_retired[63:32];
            default:
                csr_data = 32'h0;
        endcase
    end

    // Finite state machine; starts on reset
    always_ff @(posedge clock) begin
        if (reset) begin
            // Reset Registers
            for (int i = 0; i < 32; i++)
                registers[i] <= 0;
            
            reg_write_enable <= 1'b0;
            reg_write_data <= 32'b0;

            // Reset Memory Data
            mem_read_enable <= 1'b0;
            mem_write_enable <= 1'b0;

            mem_write_addr <= 32'b0;
            mem_read_addr <= 32'b0;

            mem_write_data <= 32'b0;
            write_mask <= 4'b0;

            PC <= 32'b0;
            state <= INIT;

            // Reset CSR
            cycles <= 64'b0;
            instructions_retired <= 64'b0;
        end else begin
            cycles <= cycles + 1;

            case(state)
                HALT: begin
                    state <= HALT; 
                end
                INIT: begin
`ifdef SIMULATION
                    $display("=====================================");
                    $display("%-20s %-s", "PROGRAM COUNTER", "INSTRUCTION TYPE");
                    $display("=====================================");
`endif 
                    mem_read_enable <= 1'b1;
                    state <= FETCH;
                end
                FETCH: begin
                    mem_read_enable <= 1'b0;
                    next_PC <= PC + 4;
                    state <= DECODE;
                end
                DECODE: begin
                    // Decode happens here via decoder.sv
                    fetched_instr <= mem_data;
            
                    // Calculate targets for JAL, JALR, and branches
                    jump_target <= PC + Jimm;
                    jumpr_target <= (rs1_data + Iimm) & ~32'd1;
                    branch_target <= PC + Bimm;

                    state <= EXECUTE;
                end
                EXECUTE: begin
                    // Set Write-backs to registers
                    if (isJAL || isJALR) begin
                        reg_write_data <= PC + 4;
                        reg_write_enable <= 1'b1;
                    end else if (isLUI) begin
                        reg_write_data <= Uimm;
                        reg_write_enable <= 1'b1;
                    end else if (isAUIPC) begin
                        reg_write_data <= PC + Uimm;
                        reg_write_enable <= 1'b1;
                    end else if (isALUreg || isALUimm) begin
                        reg_write_data <= aluOut;
                        reg_write_enable <= 1'b1;
                    end else if (isCSR_RS) begin
                        reg_write_data <= csr_data;
                        reg_write_enable <= 1'b1;
                    end else begin
                        reg_write_data <= 32'b0;
                        reg_write_enable <= 1'b0;
                    end

                    // Reconfigure PC based on the instruction
                    if (isJAL) begin
                        PC <= jump_target;
                    end else if (isJALR) begin
                        PC <= jumpr_target;
                    end else if (isBranch && takeBranch) begin
                        PC <= branch_target;
                    end else begin
                        PC <= next_PC;
                    end

`ifdef SIMULATION
                    if (isEBREAK) begin
                        $display("EBREAK encountered.");
                        $finish;
                    end
`endif

                    // Read or write data
                    if (isLoad) begin 
                        mem_read_enable <= 1'b1;
                        mem_read_addr <= load_addr;
                    end else if (isStore) begin
                        mem_write_enable <= 1'b1;

                        mem_write_addr <= store_addr;

                        mem_write_data <= store_data;
                        write_mask <= store_mask;
                    end

                    state <= MEMORY;
                
`ifdef SIMULATION
                // Output the program counter and the type of an operation
                case (1'b1)
                    isALUreg : $display("%-20s %-s", $sformatf("PC=  %d", PC), "ALUreg");
                    isALUimm : $display("%-20s %-s", $sformatf("PC=  %d", PC), "ALUimm"); 
                    isBranch : $display("%-20s %-s", $sformatf("PC=  %d", PC), "BRANCH"); 
                    isJAL : $display("%-20s %-s", $sformatf("PC=  %d", PC), "JAL"); 
                    isJALR : $display("%-20s %-s", $sformatf("PC=  %d", PC), "JALR"); 
                    isAUIPC : $display("%-20s %-s", $sformatf("PC=  %d", PC), "AUIPC"); 
                    isLUI : $display("%-20s %-s", $sformatf("PC=  %d", PC), "LUI"); 
                    isLoad : $display("%-20s %-s", $sformatf("PC=  %d", PC), "LOAD"); 
                    isStore : $display("%-20s %-s", $sformatf("PC=  %d", PC), "STORE"); 
                    isSYSTEM : $display("%-20s %-s", $sformatf("PC=  %d", PC), "SYSTEM"); 
                endcase
`endif 
                end
                MEMORY: begin
                    if (isLoad) begin 
                        mem_read_enable <= 1'b0;
                    end else if (isStore) begin
                        mem_write_enable <= 1'b0;
                    end

                    state <= WRITE_BACK;
                end
                WRITE_BACK: begin
                    // Write back to a register
                    if (reg_write_enable && rd != 'b0) begin
                        registers[rd] <= reg_write_data;
                    end
                    
                    // Write loaded data to a register
                    if (isLoad && rd != 'b0) begin
                        registers[rd] <= load_data;
                    end

                    instructions_retired <= instructions_retired + 1;

                    mem_read_enable <= 1'b1;
                    mem_read_addr <= PC;

                    reg_write_enable <= 1'b0;

                    state <= FETCH;
                end
                default: state <= FETCH;
            endcase
        end
    end
endmodule