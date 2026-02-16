`default_nettype none

module processor #(
    parameter MEM_INIT = "memory.mem"
) (
    input logic clock,
    input logic reset
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
    state_t state, next_state;

    // Program counter
    logic [31:0] PC, next_PC;

    // Memory register
    logic write_enable = 0;
    logic read_enable = 0;
    logic [31:0] write_data = 0;

    // Instruction
    logic [31:0] instr;

    // Instruction type outputs
    logic isALUreg, isALUimm, isLoad, isStore, isLUI, isAUIPC, isJAL;
    logic isJALR, isSYSTEM, isBranch;

    // Register addresses
    logic [4:0] rd, rs1, rs2; 

    // Function codes
    logic [2:0] funct3;
    logic [6:0] funct7;

    // Immediates
    logic [31:0] Iimm, Simm, Bimm, Uimm, Jimm;

    // Register File Data
    logic [31:0] rs1_data, rs2_data;
    logic reg_write_en;
    logic [31:0] reg_write_data;

    // ALU output
    logic [31:0] aluOut;

    // Bram memory
    bram_sdp #(
    .WIDTH(32), 
    .DEPTH(128),
    .INIT(MEM_INIT)
    ) bram_inst (
    .clock_write(clock),
    .clock_read(clock),
    .write_enable(write_enable),
    .read_enable(read_enable),
    .addr_write(PC[8:2]),       // since the depth = 128
    .addr_read(PC[8:2]),
    .data_in(write_data),
    .data_out(instr)
    );

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

    // Register File
    register_file #(
        .WIDTH(32),
        .DEPTH(32)
    ) register_file_inst (
        .clock(clock),
        .reset(reset),
        .rs1_addr(rs1),
        .rs1_data(rs1_data),
        .rs2_addr(rs2),
        .rs2_data(rs2_data),
        .write_en(reg_write_en),
        .write_data(reg_write_data),
        .rd_addr(rd)
    );

    // ALU instantiation
    alu #(
        .WIDTH(32)
    ) alu_inst (
        .rs1_data,
        .rs2_data,
        .Iimm,
        .funct3,
        .funct7,
        .isALUreg,
        .aluOut
    );

    // Start on reset; otherwise, change states
    always_ff @(posedge clock)
    begin
        if (reset) begin
            state <= INIT;
            PC <= 32'b0;
        end
        else begin
            state <= next_state;
            PC <= next_PC;


        end
    end

    // Finite State Machine
    always_comb begin
        next_PC = PC;
        next_state = state;

        // Memory
        read_enable = 0;
        write_enable = 0;
        write_data = 32'b0;

        // Register File
        reg_write_en = 0;
        reg_write_data = 32'b0;

        case(state)
        HALT : begin
            next_state = HALT;
        end
        INIT : begin
            next_state = FETCH;
        end
        FETCH : begin
            read_enable = 1;
            next_state = DECODE;
        end
        DECODE : begin
            next_state = EXECUTE;
        end
        EXECUTE : begin
            // Implement JAL and JALR instructions
            if (isJAL || isJALR) begin
                reg_write_data = PC +4;
                next_state = WRITE_BACK;
            end

            // Implement ALUimm and ALUreg instructions
            if (isALUimm || isALUreg)
                next_state = WRITE_BACK;

            // Write the output of ALU to the register file if it's not JAL or not JALR
            reg_write_data = aluOut;

            // Reconfigure nextPC based on the instruction
            next_PC = isJAL ? PC + Jimm :
                      isJALR ? rs1_data + Iimm :
                      PC + 4;

            next_state = MEMORY;

        // Print OPCODES for the sake of simulation
        case (1'b1)
            isALUreg : $display("PC=%d ALUreg", PC);
            isALUimm: $display("PC=%d ALUimm", PC);
            isBranch : $display("PC=%d BRANCH", PC);
            isJAL : $display("PC=%d JAL", PC);
            isJALR : $display("PC=%d JALR", PC);
            isAUIPC : $display("PC=%d AUIPC", PC);
            isLUI : $display("PC=%d LUI", PC);
            isLoad : $display("PC=%d LOAD", PC);
            isStore : $display("PC=%d STORE", PC);
            isSYSTEM : $display("PC=%d SYSTEM", PC);
        endcase
        end
        MEMORY : begin
            next_state = WRITE_BACK;
        end
        WRITE_BACK : begin
            next_state = FETCH;

            // For the sake of simulation, stop at the last instuction 
            if (PC == 'd292)
                next_state = HALT;
        end
        default: next_state = HALT;
        endcase
    end

endmodule
