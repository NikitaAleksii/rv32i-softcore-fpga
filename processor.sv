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
    localparam NOP = 32'b00000000000000000000000000010011; // addi x0, x0, 0

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
    logic [31:0] f_PC, fd_PC, de_PC;
    logic [31:0] fd_next_PC, de_next_PC, em_next_PC, mw_next_PC;

    // Instructions
    logic [31:0] d_instruction, de_instruction, em_instruction, mw_instruction;
    assign d_instruction = mem_data;
    
    // Instruction type outputs
    logic d_isALUreg, e_isALUreg;
    logic d_isALUimm, e_isALUimm;
    logic d_isLoad, e_isLoad;
    logic d_isStore, e_isStore;
    logic d_isLUI, e_isLUI;
    logic d_isAUIPC, e_isAUIPC;
    logic d_isJAL, e_isJAL;
    logic d_isJALR, e_isJALR;
    logic d_isSYSTEM, e_isSYSTEM;
    logic d_isBranch, e_isBranch;
    logic d_isEBREAK, e_isEBREAK;
    logic d_isECALL, e_isECALL; 
    logic d_isCSR_RS, e_isCSR_RS;

    // Register addresses
    logic [4:0] d_rd, e_rd; 
    logic [4:0] d_rs1, e_rs1;
    logic [4:0] d_rs2, e_rs2; 

    // Additional opcodes
    logic [2:0] d_funct3, e_funct3;
    logic [6:0] d_funct7, e_funct7;

    // Immediates 
    logic [31:0] d_Iimm, e_Iimm; 
    logic [31:0] d_Simm, e_Simm;
    logic [31:0] d_Bimm, e_Bimm;
    logic [31:0] d_Uimm, e_Uimm;
    logic [31:0] d_Jimm, e_Jimm;

    // Register data
    logic [31:0] de_rs1_data; 
    logic [31:0] de_rs2_data;

    // Registers
    logic [31:0] registers [0:31];
    logic em_reg_write_enable, mw_reg_write_enable;
    logic [31:0] em_reg_write_data, mw_reg_write_data;

    // Each stage's view of the instruction it is currently processing
    // Aliases for the pipeline registers (d_, de_, em_, mw_) so stage-local
    // logic can reference its own instruction by name rather than by boundary
    logic [31:0] d_effective_instruction, e_effective_instruction, m_effective_instruction, w_effective_instruction;
    assign d_effective_instruction = d_instruction;
    assign e_effective_instruction = de_instruction;
    assign m_effective_instruction = em_instruction;
    assign w_effective_instruction = mw_instruction;

    // Decoder for the Decoder stage
    decoder decoder_isnt_d (
        .instr(d_effective_instruction),
        .isALUreg(d_isALUreg),
        .isALUimm(d_isALUimm),
        .isLoad(d_isLoad),
        .isStore(d_isStore),
        .isLUI(d_isLUI),
        .isAUIPC(d_isAUIPC),
        .isJAL(d_isJAL),
        .isJALR(d_isJALR),
        .isSYSTEM(d_isSYSTEM),
        .isBranch(d_isBranch),
        .isEBREAK(d_isEBREAK),
        .isECALL(d_isECALL),
        .isCSR_RS(d_isCSR_RS),
        .rd(d_rd),
        .rs1(d_rs1),
        .rs2(d_rs2),
        .funct3(d_funct3),
        .funct7(d_funct7),
        .Iimm(d_Iimm),
        .Simm(d_Simm),
        .Bimm(d_Bimm),
        .Uimm(d_Uimm),
        .Jimm(d_Jimm)
    );

    // Decoder for the Execute stage
    decoder decoder_isnt_e (
        .instr(e_effective_instruction),
        .isALUreg(e_isALUreg),
        .isALUimm(e_isALUimm),
        .isLoad(e_isLoad),
        .isStore(e_isStore),
        .isLUI(e_isLUI),
        .isAUIPC(e_isAUIPC),
        .isJAL(e_isJAL),
        .isJALR(e_isJALR),
        .isSYSTEM(e_isSYSTEM),
        .isBranch(e_isBranch),
        .isEBREAK(e_isEBREAK),
        .isECALL(e_isECALL),
        .isCSR_RS(e_isCSR_RS),
        .rd(e_rd),
        .rs1(e_rs1),
        .rs2(e_rs2),
        .funct3(e_funct3),
        .funct7(e_funct7),
        .Iimm(e_Iimm),
        .Simm(e_Simm),
        .Bimm(e_Bimm),
        .Uimm(e_Uimm),
        .Jimm(e_Jimm)
    );

    // ALU output
    logic [31:0] e_aluOut;
    logic e_EQ; // Equal
    logic e_LT; // Less than
    logic e_LTU; // Less than unsigned

    // ALU instantiation
    alu #(
        .WIDTH(32)
    ) alu_inst (
        .isBranch(e_isBranch),
        .rs1_data(de_rs1_data),
        .rs2_data(de_rs2_data),
        .Iimm(e_Iimm),
        .funct3(e_funct3),
        .funct7(e_funct7),
        .isALUreg(e_isALUreg),
        .aluOut(e_aluOut),
        .EQ(e_EQ),
        .LT(e_LT),
        .LTU(e_LTU)
    );

    // Initialize target addresses
    logic [31:0] de_jump_target;
    logic [31:0] de_jumpr_target;
    logic [31:0] de_branch_target;

    // Adjusted load and store addresses
    logic [31:0] de_adjusted_load_addr, em_adjusted_load_addr, mw_adjusted_load_addr;
    logic [31:0] de_adjusted_store_addr;

    // Handle LOAD by computing bytes and halfwords and assigning them to load data output
    logic [31:0] w_load_addr;
    logic [31:0] w_load_word; 
    logic [31:0] w_load_data; // Proccessed data to be written back to registers

    assign w_load_word = mem_data;
    assign w_load_addr = mw_adjusted_load_addr;

    load_helper load_helper_inst(
        .funct3(mw_funct3),
        .mem_data(w_load_word),
        .load_data(w_load_data),
        .load_addr(w_load_addr)
    );

    // Handle STORE by computing bytes and halfwords and assigning them to store data output
    logic [31:0] e_store_addr;
    logic [31:0] e_store_word; 
    logic [31:0] e_store_data;
    logic [3:0]  e_store_mask;

    assign e_store_addr = de_adjusted_store_addr;
    assign e_store_word = de_rs2_data;

    store_helper store_helper_inst(
        .funct3(e_funct3),
        .store_data(e_store_data),
        .store_addr(e_store_addr),
        .store_mask(e_store_mask),
        .store_word(e_store_word)
    );

    // Handle Branches
    logic e_takeBranch;

    always_comb begin
        case(e_funct3)
            3'b000 : e_takeBranch = e_EQ; // BEQ
            3'b001 : e_takeBranch = !e_EQ; // BNE
            3'b100 : e_takeBranch = e_LT; // BLT
            3'b101 : e_takeBranch = !e_LT; // BGE
            3'b110 : e_takeBranch = e_LTU; // BLTU
            3'b111 : e_takeBranch = !e_LTU; // BGEU
            default: e_takeBranch = 1'b0;
        endcase
    end

    // E/M and M/W pipeline register fields for memory-stage signals.
    //
    // Both Fetch (instruction reads) and Execute/Memory (data reads/writes) 
    // share the same memory bus. Writes take priority —
    // if Execute is writing, Fetch is suppressed. Otherwise, a pending data
    // read takes priority over an instruction fetch
    logic [4:0] em_rd, mw_rd;
    logic [2:0] em_funct3, mw_funct3;

    logic em_isLoad, mw_isLoad;
    logic em_isStore;

    logic f_mem_read_enable, em_mem_read_enable;
    logic [21:0] f_mem_read_addr, em_mem_read_addr;
    logic [31:0] em_mem_read_data;

    logic em_mem_write_enable;
    logic [21:0] em_mem_write_addr;
    logic [31:0] em_mem_write_data;
    logic [3:0] em_mem_write_mask;

    assign mem_read_enable = (f_mem_read_enable || em_mem_read_enable) && !em_mem_write_enable;
    assign mem_read_addr = (em_mem_read_enable ? em_mem_read_addr : (f_mem_read_enable ? f_mem_read_addr : 0));

    assign mem_write_enable = em_mem_write_enable;
    assign mem_write_addr = em_mem_write_addr;
    assign mem_write_data = em_mem_write_data;
    assign write_mask = em_mem_write_mask;

    // Initialize CSR registers
    logic [63:0] cycles;
    logic [63:0] instructions_retired;

    // Combinatorial logic to get CSR data
    logic [31:0] e_csr_data;

    always_comb begin
        case(e_Iimm[11:0])
            12'hC00:
                e_csr_data = cycles[31:0];
            12'hC80:
                e_csr_data = cycles[63:32];
            12'hC02:
                e_csr_data = instructions_retired[31:0];
            12'hC82:
                e_csr_data = instructions_retired[63:32];
            default:
                e_csr_data = 32'h0;
        endcase
    end

    // Finite state machine; starts on reset
    always_ff @(posedge clock) begin
        if (reset) begin
            // Reset Registers
            for (int i = 0; i < 32; i++)
                registers[i] <= 0;
            
            // Reset PC's
            f_PC <= '0; fd_PC <= '0; de_PC <= '0;
            fd_next_PC <= '0; de_next_PC <= '0; em_next_PC <= '0; mw_next_PC <= '0;

            // Flush pipeline with NOPs so no stale instruction retires during startup
            de_instruction <= NOP; em_instruction <= NOP; mw_instruction <= NOP;

            // Reset source registers
            de_rs1_data <= '0;
            de_rs2_data <= '0;

            // Reset destination registers
            em_rd <= '0; mw_rd <= '0;

            // Reset function fields
            em_funct3 <= '0; mw_funct3 <= '0;

            // Reset adjusted load and store addresses
            de_adjusted_load_addr <= '0; em_adjusted_load_addr <= '0; mw_adjusted_load_addr <= '0;
            de_adjusted_store_addr <= '0;

            // Reset branch and jump targets
            de_branch_target <= '0;
            de_jump_target <= '0;
            de_jumpr_target <= '0;

            // Reset load/store control flags
            em_isLoad <= 0; mw_isLoad <= 0;
            em_isStore <= 0;

            // Reset register writeback path
            em_reg_write_enable <= 0; mw_reg_write_enable <= 0;
            em_reg_write_data <= '0; mw_reg_write_data <= '0;

            // Reset memory bus signals
            f_mem_read_enable <= 0; em_mem_read_enable <= 0;
            f_mem_read_addr <= '0; em_mem_read_addr <= '0;
            em_mem_read_data <= '0;

            // Reset memory write path
            em_mem_write_enable <= 0;
            em_mem_write_data <= '0;
            em_mem_write_mask <= '0;
            em_mem_write_addr <= '0;

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
                    f_mem_read_enable <= 1'b1;
                    state <= FETCH;
                end
                FETCH: begin
                    f_mem_read_enable <= 1'b0;

                    fd_next_PC <= (f_PC + 4);
                    fd_PC <= f_PC;

                    state <= DECODE;
                end
                DECODE: begin
                    // Calculate targets for JAL, JALR, and branches
                    de_jump_target <= fd_PC + d_Jimm;
                    de_jumpr_target <= (registers[d_rs1] + d_Iimm) & ~32'd1;
                    de_branch_target <= fd_PC + d_Bimm;

                    de_adjusted_load_addr <= registers[d_rs1] + d_Iimm;
                    de_adjusted_store_addr <= registers[d_rs1] + d_Simm;

                    de_next_PC <= fd_next_PC;
                    de_PC <= fd_PC;

                    de_rs1_data <= registers[d_rs1];
                    de_rs2_data <= registers[d_rs2];

                    de_instruction <= d_effective_instruction;

                    state <= EXECUTE;
                end
                EXECUTE: begin
                    // Set Write-backs to registers
                    if (e_isJAL || e_isJALR) begin
                        em_reg_write_data <= de_PC + 4;
                        em_reg_write_enable <= 1'b1;
                    end else if (e_isLUI) begin
                        em_reg_write_data <= e_Uimm;
                        em_reg_write_enable <= 1'b1;
                    end else if (e_isAUIPC) begin
                        em_reg_write_data <= de_PC + e_Uimm;
                        em_reg_write_enable <= 1'b1;
                    end else if (e_isALUreg || e_isALUimm) begin
                        em_reg_write_data <= e_aluOut;
                        em_reg_write_enable <= 1'b1;
                    end else if (e_isCSR_RS) begin
                        em_reg_write_data <= e_csr_data;
                        em_reg_write_enable <= 1'b1;
                    end else begin
                        em_reg_write_data <= 32'b0;
                        em_reg_write_enable <= 1'b0;
                    end

                    // Reconfigure PC based on the instruction
                    if (e_isJAL) begin
                        em_next_PC <= de_jump_target;
                    end else if (e_isJALR) begin
                        em_next_PC <= de_jumpr_target;
                    end else if (e_isBranch && e_takeBranch) begin
                        em_next_PC <= de_branch_target;
                    end else begin
                        em_next_PC <= de_next_PC;
                    end

`ifdef SIMULATION
                    if (e_isEBREAK) begin
                        $display("EBREAK encountered.");
                        $finish;
                    end
`endif

                    // Read or write data
                    if (e_isLoad) begin 
                        em_mem_read_enable <= 1'b1;
                        em_mem_read_addr <= de_adjusted_load_addr;
                    end else if (e_isStore) begin
                        em_mem_write_enable <= 1'b1;
                        em_mem_write_addr <= de_adjusted_store_addr;
                        em_mem_write_data <= e_store_data;
                        em_mem_write_mask <= e_store_mask;
                    end

                    em_rd <= e_rd;
                    em_funct3 <= e_funct3;

                    em_isStore <= e_isStore;
                    em_isLoad <= e_isLoad;

                    em_adjusted_load_addr <= de_adjusted_load_addr;
                    em_instruction <= e_effective_instruction;

                    state <= MEMORY;
                
`ifdef SIMULATION
                // Output the program counter and the type of an operation
                case (1'b1)
                    e_isALUreg : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "ALUreg");
                    e_isALUimm : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "ALUimm"); 
                    e_isBranch : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "BRANCH"); 
                    e_isJAL : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "JAL"); 
                    e_isJALR : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "JALR"); 
                    e_isAUIPC : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "AUIPC"); 
                    e_isLUI : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "LUI"); 
                    e_isLoad : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "LOAD"); 
                    e_isStore : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "STORE"); 
                    e_isSYSTEM : $display("%-20s %-s", $sformatf("PC=  %d", de_PC), "SYSTEM"); 
                endcase
`endif 
                end
                MEMORY: begin
                    if (em_isLoad) begin 
                        em_mem_read_enable <= 1'b0;
                    end else if (em_isStore) begin
                        em_mem_write_enable <= 1'b0;
                    end

                    mw_rd <= em_rd;
                    mw_funct3 <= em_funct3;

                    mw_isLoad <= em_isLoad;

                    mw_next_PC <= em_next_PC;

                    mw_adjusted_load_addr <= em_adjusted_load_addr;

                    mw_reg_write_data <= em_reg_write_data;
                    mw_reg_write_enable <= em_reg_write_enable;

                    mw_instruction <= m_effective_instruction;

                    state <= WRITE_BACK;
                end
                WRITE_BACK: begin
                    // Write back to a register
                    if (mw_reg_write_enable && mw_rd != 'b0) begin
                        registers[mw_rd] <= mw_reg_write_data;
                    end
                    
                    // Write loaded data to a register
                    if (mw_isLoad && mw_rd != 'b0) begin
                        registers[mw_rd] <= w_load_data;
                    end

                    f_mem_read_enable <= 1'b1;
                    f_mem_read_addr <= mw_next_PC;
                    f_PC <= mw_next_PC;

                    mw_reg_write_enable <= 1'b0;

                    instructions_retired <= instructions_retired + 1;
                    state <= FETCH;
                end
                default: state <= FETCH;
            endcase
        end
    end
endmodule