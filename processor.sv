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
    logic [31:0] mem_addr;
    logic [31:0] mem_data;

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
    logic EQ; // Equal
    logic LT; // Less than
    logic LTU; // Less than unsigned

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
        .addr_write(mem_addr[8:2]),      // Use the same memory address for read/write
        .addr_read(mem_addr[8:2]),       // Use the same memory address for read/write
        .data_in(write_data),
        .data_out(mem_data)              // Use memory for both instuctions and data
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

    // Start on reset; otherwise, change states
    always_ff @(posedge clock) begin
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
                mem_addr = PC;
                next_state = DECODE;
            end
            DECODE : begin
                instr = mem_data;
                next_state = EXECUTE;
            end
            EXECUTE : begin
                logic takeBranch;

                // Implement Branches
                case(funct3)
                    3'b000 : takeBranch = EQ; // BEQ
                    3'b001 : takeBranch = !EQ; // BNE
                    3'b100 : takeBranch = LT; // BLT
                    3'b101 : takeBranch = !LT; // BGE
                    3'b110 : takeBranch = LTU; // BLTU
                    3'b111 : takeBranch = !LTU; // BGEU
                    default: takeBranch = 1'b0;
                endcase

                // Reconfigure nextPC based on the instruction
                if (isJAL) begin
                    next_PC = PC + Jimm;
                end else if (isJALR) begin
                    next_PC = rs1_data + Iimm;
                end else if (takeBranch && isBranch) begin
                    next_PC = PC + Bimm;
                end else begin
                    next_PC = PC + 4;
                end

                // Write-back value: PC + 4 for JAL and JALR instructions, aluOut for the rest
                if (isJAL || isJALR) begin
                    reg_write_data = PC + 4;
                end else if (isLUI) begin
                    reg_write_data = Uimm;
                end else if (isAUIPC) begin
                    reg_write_data = PC + Uimm;
                end else begin
                    reg_write_data = aluOut;
                end

                // If either Load or Store is asserted, go to MEMORY; otherwise, go to WRITE_BACK
                if (isLoad || isStore) begin
                    next_state = MEMORY;
                end
                else begin
                    next_state = WRITE_BACK;
                end

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
                logic [31:0] loadstore_addr; // Address of the data to be loaded
                logic [31:0] loadstore_data; // Data to be loaded
                logic [15:0] loadstore_halfword; // Half word
                logic [7:0] loadstore_byte; // Byte

                loadstore_addr = rs1_data + (isStore ? Simm : Iimm);
                mem_addr = loadstore_addr;

                if (isLoad) begin
                    read_enable = 1;
                    
                    loadstore_halfword = loadstore_addr[1] ? mem_data[31:16] : mem_data[15:0];
                    loadstore_byte = loadstore_addr[0] ? loadstore_halfword[15:8] : loadstore_halfword[7:0];

                    case (funct3)
                        3'b000 : loadstore_data = {{24{loadstore_byte[7]}}, loadstore_byte}; // LB (sign-extend)
                        3'b001 : loadstore_data = {{16{loadstore_halfword[15]}}, loadstore_halfword}; // LH (sign-extend)
                        3'b010 : loadstore_data = mem_data; // LW
                        3'b100 : loadstore_data = {24'b0, loadstore_byte}; // LBU (zero-extend)
                        3'b101 : loadstore_data = {16'b0, loadstore_halfword}; // LHU (zero-extend)
                        default : loadstore_data = 32'b0;
                    endcase
                    reg_write_data = loadstore_data;
                end else begin
                    write_enable = 1;
                    mem_addr = loadstore_addr;
                    write_data = loadstore_data;
                end
                next_state = WRITE_BACK;
            end
            WRITE_BACK : begin
                // Write to registers
                if (isALUreg || isALUimm || isLUI || isAUIPC || isJAL || isJALR || isLoad) begin
                    reg_write_en = 1;
                end
                
                next_state = FETCH;

                // For the sake of simulation, stop at the last instuction 
                if (PC == 'd292)
                    next_state = HALT;
            end
            default: next_state = HALT;
        endcase
    end
    
endmodule