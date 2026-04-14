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
    localparam NOP = 32'b0000000_00000_00000_000_00000_0110011; // addi x0, x0, 0

    // Machine States
    typedef enum { 
        HALT,
        INIT,
        RUN
    } state_t;

    // Current and next states
    state_t state;

    // Program counter
    logic [31:0] f_PC, f_prev_PC; // f_prev_PC lets Fetch undo a speculative PC advance
    logic [31:0] d_PC, de_PC;
    logic [31:0] fd_next_PC, de_next_PC, em_next_PC, mw_next_PC;
    logic f_pending; // lock on fetch to make sure that there is no conflict between fetch and memory accesses since they share the same bus

    // Instructions
    logic [31:0] d_instruction, de_instruction, em_instruction, mw_instruction;
    assign d_instruction = pb_instruction;
    
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
    assign d_effective_instruction = ((flush_decode || pb_empty)) ? NOP : d_instruction;
    assign e_effective_instruction = (flush_execute ? NOP : de_instruction);
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

    logic conflict_de, conflict_dm, conflict_dw;

    conflict_checker de_register_checker_inst (
        .R_instruction(d_effective_instruction),
        .W_instruction(e_effective_instruction),
        .conflict(conflict_de)
    );

    conflict_checker dm_register_checker_inst (
        .R_instruction(d_effective_instruction),
        .W_instruction(m_effective_instruction),
        .conflict(conflict_dm)
    );

    conflict_checker dw_register_checker_inst (
        .R_instruction(d_effective_instruction),
        .W_instruction(w_effective_instruction),
        .conflict(conflict_dw)
    );

    // Register value not yet updated
    logic conflict_d_emw;
    assign conflict_d_emw = (conflict_de || conflict_dm || conflict_dw);

    // Fetch wants to read from memory. Write wants to read/write data from memory
    logic conflict_fm;
    assign conflict_fm = (em_isLoad || em_isStore);

    // Fetch wants to read from memory. Write-back is writing a result to the register file
    logic conflict_fw;
    assign conflict_fw = mw_isLoad;

    // Pipeline fetches instructions from the wrong address. By the time branch resolves in E, F and D have already grabbed two instructions
    logic control_hazard;
    assign control_hazard = (e_isJAL || e_isJALR || (e_isBranch && e_takeBranch));

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

    // Flush flags
    logic flush_decode, flush_execute;

    // Prefetch buffer
    localparam PREFETCH_BUFFER_DEPTH = 8;

    logic [63:0] prefetch_buffer [PREFETCH_BUFFER_DEPTH];
    logic [$clog2(PREFETCH_BUFFER_DEPTH)-1:0] pb_write;
    logic [$clog2(PREFETCH_BUFFER_DEPTH)-1:0] pb_read;
    logic [$clog2(PREFETCH_BUFFER_DEPTH)-1:9] pb_count; // arithmetic that tracks the net change in buffer occupancy each cycle

    logic pb_full;
    assign pb_full = (pb_count == PREFETCH_BUFFER_DEPTH);

    logic pb_empty;
    assign pb_empty = (pb_count == 0);

    logic [31:0] pb_instruction;
    assign pb_instruction = prefetch_buffer[pb_read][31:0];

    logic [31:0] pb_pc;
    assign pb_pc = prefetch_buffer[pb_read][63:32];
    assign d_PC = pb_pc;

    logic pb_produced;  // Asserted when the buffer successfully writes a new instruction
    assign pb_produced = (f_pending && !conflict_fm && !conflict_fw && !pb_full);

    logic pb_consumed;  // Asserted when the decoder successfully reads an instruction
    assign pb_consumed = (!conflict_d_emw && !pb_empty);

    
    // Finite state machine; starts on reset
    always_ff @(posedge clock) begin
        if (reset) begin
            // Reset Registers
            for (int i = 0; i < 32; i++)
                registers[i] <= 0;
            
            // Reset PC's
            f_PC <= '0; de_PC <= '0;
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

            // Reset flushes
            flush_decode <= 0;
            flush_execute <= 0;

            f_pending <= 0;

            pb_read <= '0; pb_write <= '0; pb_count <= '0;
        end else begin
            cycles <= cycles + 1;

            // Reset since they last for one clock cycle
            flush_decode <= 0;
            flush_execute <= 0;

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

                    f_pending <= 0;

                    state <= RUN;
                end
                RUN: begin
`ifdef SIMULATION
                    $display("FETCH");

                    if (conflict_fm) begin
                        $display("Structural Hazard Fetch-Memory : Memory Bus");
                    end

                    if (conflict_fw) begin
                        $display("Structural Hazard Fetch-WriteBack : Register File");
                    end
`endif 
                    // Issue a new fetch request
                    // If the bus is free and the buffer has room, advance the PC and issue a read for the next instruction
                    if (!conflict_fm && !pb_full) begin
                        f_prev_PC <= f_PC;
                        f_PC <= f_PC + 4;

                        f_mem_read_addr <= f_PC + 4;
                        f_mem_read_enable <= 1'b1;

                        f_pending <= 1'b1;
                    end 
                    // If the bus is taken or buffer is full, reissue the same address without advancing
                    else begin
                        f_mem_read_addr <= f_PC;
                        f_mem_read_enable <= 1'b1;

                        f_pending <= 0;
                    end
                    
                    // Handle the response from a pending request
                    // If a response is ready and no conflicts, write the returned instruction into the buffer 
                    if (f_pending) begin
                        if (!conflict_fm && !conflict_fw && !pb_full) begin
                            prefetch_buffer[pb_write] <= {f_prev_PC, mem_data};

                            pb_write <= pb_write + 1;
                            pb_count <= pb_count + pb_produced - pb_consumed;
                        end 
                        
                        // If there is a conflict roll back
                        else begin
                            f_PC <= f_prev_PC; // undo PC

                            f_mem_read_addr <= f_prev_PC; // retry from the same address
                            f_mem_read_enable <= 1'b1;

                            f_pending <= 0;
                        end
                    end

`ifdef SIMULATION
                    $display("DECODE");

                    if (conflict_d_emw) begin
                        $display("Data Hazard : Decode - Execute/Memory/WriteBack");
                    end
`endif 
                    if (!conflict_d_emw && !pb_empty) begin
                        // Consume from the prefetch buffer
                        pb_read <= pb_read + 1;
                        pb_count <= pb_count + pb_produced - pb_consumed;

                        // Calculate targets for JAL, JALR, and branches
                        de_jump_target <= d_PC + d_Jimm;
                        de_jumpr_target <= (registers[d_rs1] + d_Iimm) & ~32'd1;
                        de_branch_target <= d_PC + d_Bimm;

                        de_adjusted_load_addr <= registers[d_rs1] + d_Iimm;
                        de_adjusted_store_addr <= registers[d_rs1] + d_Simm;

                        de_PC <= d_PC;

                        de_rs1_data <= registers[d_rs1];
                        de_rs2_data <= registers[d_rs2];

                        de_instruction <= d_effective_instruction;
                    end else begin
                        de_instruction <= NOP;
                    end

`ifdef SIMULATION
                    $display("EXECUTE");
`endif 
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
                        em_reg_write_enable <= (e_effective_instruction != NOP ? 1'b1 : 1'b0);
                    end else if (e_isCSR_RS) begin
                        em_reg_write_data <= e_csr_data;
                        em_reg_write_enable <= 1'b1;
                    end else begin
                        em_reg_write_data <= 32'b0;
                        em_reg_write_enable <= 1'b0;
                    end

                    // Reconfigure PC based on the instruction
                    if (e_isJAL) begin
                        f_PC <= de_jump_target;

                        pb_read <= 0; pb_write <= 0; pb_count <= 0;

                        f_mem_read_addr <= de_jump_target;
                        f_mem_read_enable <= 1'b1;

                        f_pending <= 0;

                        flush_decode <= 1;
                        flush_execute <= 1;
                    end else if (e_isJALR) begin
                        f_PC <= de_jumpr_target;

                        pb_read <= 0; pb_write <= 0; pb_count <= 0;

                        f_mem_read_addr <= de_jumpr_target;
                        f_mem_read_enable <= 1'b1;

                        f_pending <= 0;

                        flush_decode <= 1;
                        flush_execute <= 1;
                    end else if (e_isBranch && e_takeBranch) begin
                        f_PC <= de_branch_target;

                        pb_read <= 0; pb_write <= 0; pb_count <= 0;

                        f_mem_read_addr <= de_branch_target;
                        f_mem_read_enable <= 1'b1;

                        f_pending <= 0;

                        flush_decode <= 1;
                        flush_execute <= 1;
                    end 

    `ifdef SIMULATION
                    if (e_isEBREAK) begin
                        $display("EBREAK encountered.");
                //        $finish;
                    end
    `endif

                    // Read or write data
                    if (e_isLoad) begin
                        em_mem_read_enable <= 1'b1;
                        em_mem_read_addr <= de_adjusted_load_addr;
                        em_mem_write_enable <= 1'b0;
                    end else if (e_isStore) begin
                        em_mem_write_enable <= 1'b1;
                        em_mem_write_addr <= de_adjusted_store_addr;
                        em_mem_write_data <= e_store_data;
                        em_mem_write_mask <= e_store_mask;
                        em_mem_read_enable <= 1'b0;
                    end else begin
                        em_mem_read_enable <= 1'b0;
                        em_mem_write_enable <= 1'b0;
                    end

                    em_rd <= e_rd;
                    em_funct3 <= e_funct3;

                    em_isStore <= e_isStore;
                    em_isLoad <= e_isLoad;

                    em_adjusted_load_addr <= de_adjusted_load_addr;
                    em_instruction <= e_effective_instruction;
                
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

`ifdef SIMULATION
                    $display("MEMORY");
`endif 
                    mw_rd <= em_rd;
                    mw_funct3 <= em_funct3;

                    mw_isLoad <= em_isLoad;

                    mw_adjusted_load_addr <= em_adjusted_load_addr;

                    mw_reg_write_data <= em_reg_write_data;
                    mw_reg_write_enable <= em_reg_write_enable;

                    mw_instruction <= m_effective_instruction;

`ifdef SIMULATION
                    $display("WRITE-BACK");
`endif 

                    // Write back to a register
                    if (mw_reg_write_enable && mw_rd != 'b0) begin
                        registers[mw_rd] <= mw_reg_write_data;
                    end
                    
                    // Write loaded data to a register
                    if (mw_isLoad && mw_rd != 'b0) begin
                        registers[mw_rd] <= w_load_data;
                    end

                    if (w_effective_instruction != NOP) begin
                        instructions_retired <= instructions_retired + 1;
                    end
                end
                default: state <= HALT;
            endcase
        end
    end
endmodule