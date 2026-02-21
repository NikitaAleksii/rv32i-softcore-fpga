`default_nettype none

module processor #(
    parameter MEM_INIT = "memory.mem"
) (
    input logic clock,
    input logic reset
);
    // Set memory parameters
    localparam MEM_DEPTH=4096;
    localparam MEM_ADDR_WIDTH=$clog2(MEM_DEPTH);

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

    // Jump and branch addresses
    logic [31:0] jump_target;
    logic [31:0] jumpr_target;
    logic [31:0] branch_target;

    // Memory Registers
    logic mem_write_enable = 0;
    logic mem_read_enable = 0;

    logic [3:0] write_mask;
    logic [31:0] mem_write_data = 0;

    logic [31:0] mem_read_addr;
    logic [31:0] mem_write_addr;

    logic [31:0] mem_data;

    // Instruction
    logic [31:0] instr;

    // Instruction type outputs
    logic isALUreg, isALUimm, isLoad, isStore, isLUI, isAUIPC, isJAL;
    logic isJALR, isSYSTEM, isBranch;

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

    // Bram memory
    bram_sdp #(
        .WIDTH(32), 
        .DEPTH(MEM_DEPTH),
        .INIT(MEM_INIT)
    ) bram_inst (
        .clock_write(clock),
        .clock_read(clock),
        .write_enable(mem_write_enable),
        .read_enable(mem_read_enable),
        .mem_mask_write(write_mask),
        .addr_write(mem_write_addr[MEM_ADDR_WIDTH+1:2]),   
        .addr_read(mem_read_addr[MEM_ADDR_WIDTH+1:2]),      
        .data_in(mem_write_data),
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
    logic [31:0] load_addr;
    assign load_addr = rs1_data + Iimm;

    logic [31:0] load_data;
    
    logic [15:0] load_halfword;
    logic [7:0] load_byte;

    assign load_halfword = load_addr[1] ? mem_data[31:16] : mem_data[15:0];
    assign load_byte = (load_addr[1:0] == 2'b00 ? mem_data[7:0] : (load_addr[1:0] == 2'b01 ? mem_data[15:8] : (load_addr[1:0] == 2'b10 ? mem_data[23:16] : mem_data[31:24])));

    logic halfword_sign;
    logic byte_sign;

    assign halfword_sign = load_halfword[15];
    assign byte_sign = load_byte[7];

    always_comb begin
        case (funct3) 
            3'b000 : load_data = {{24{byte_sign}}, load_byte}; // LB (sign-extend)
            3'b001 : load_data = {{16{halfword_sign}}, load_halfword}; // LH (sign-extend)
            3'b010 : load_data = mem_data; // LW
            3'b100 : load_data = {24'b0, load_byte}; // LBU (zero-extend)
            3'b101 : load_data = {16'b0, load_halfword}; // LHU (zero-extend)
            default : load_data = 32'b0;
        endcase
    end

    // Handle STORE by computing bytes and halfwords and assigning them to store data output
    logic [31:0] store_addr;
    assign store_addr = rs1_data + Simm;

    logic [31:0] store_data;
    logic [3:0] store_mask;

    logic [15:0] store_halfword;
    logic [7:0] store_byte;

    assign store_halfword = rs2_data[15:0];
    assign store_byte = rs2_data[7:0];

    // Use mask to store particular bits
    logic [3:0] halfword_mask;
    logic [3:0] byte_mask;

    assign halfword_mask = store_addr[1] ? 4'b1100 : 4'b0011;
    assign byte_mask = (store_addr[1:0] == 2'b00 ? 4'b0001 : (store_addr[1:0] == 2'b01 ? 4'b0010 : (store_addr[1:0] == 2'b10 ? 4'b0100 : 4'b1000)));

    always_comb begin
        case(funct3)
            3'b000 : begin 
                store_data = {store_byte, store_byte, store_byte, store_byte}; // SB
                store_mask = byte_mask;
            end
            3'b001 : begin
                store_data = {store_halfword, store_halfword}; // SH
                store_mask = halfword_mask;
            end
            3'b010 : begin
                store_data = rs2_data; // SW
                store_mask = 4'b1111;
            end
            default: begin
                store_data = 32'b0;
                store_mask = 4'b0000;
            end
        endcase
    end

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

    // Finite state machine; starts on reset
    always_ff @(posedge clock) begin
        if (reset) begin
            // Reset Registers
            registers[0] <= 32'b0; registers[1] <= 32'b0; registers[2] <= 32'b0; registers[3] <= 32'b0; 
            registers[4] <= 32'b0; registers[5] <= 32'b0; registers[6] <= 32'b0; registers[7] <= 32'b0;
            registers[8] <= 32'b0; registers[9] <= 32'b0; registers[10] <= 32'b0; registers[11] <= 32'b0;
            registers[12] <= 32'b0; registers[13] <= 32'b0; registers[14] <= 32'b0; registers[15] <= 32'b0;
            registers[16] <= 32'b0; registers[17] <= 32'b0; registers[18] <= 32'b0; registers[19] <= 32'b0;
            registers[20] <= 32'b0; registers[21] <= 32'b0; registers[22] <= 32'b0; registers[23] <= 32'b0;
            registers[24] <= 32'b0; registers[25] <= 32'b0; registers[26] <= 32'b0; registers[27] <= 32'b0;
            registers[28] <= 32'b0; registers[29] <= 32'b0; registers[30] <= 32'b0; registers[31] <= 32'b0;

            reg_write_enable <= 1'b0;
            reg_write_data <= 32'b0;

            // Reset Memory Data
            mem_read_enable <= 1'b1;
            mem_write_enable <= 1'b0;

            mem_write_addr <= 32'b0;
            mem_read_addr <= 32'b0;

            mem_write_data <= 32'b0;
            write_mask <= 4'b0;

            PC <= 32'b0;
            state <= INIT;
        end else begin
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
                    state <= FETCH;
                end
                FETCH: begin
                    mem_read_enable <= 1'b0;
                    next_PC <= PC + 4;
                    state <= DECODE;
                end
                DECODE: begin
                    // Decode happens here via decoder.sv
                    instr <= mem_data;
                    state <= EXECUTE;
                end
                EXECUTE: begin
                    // Calculate targets for JAL, JALR, and branches
                    jump_target = PC + Jimm;
                    jumpr_target = (rs1_data + Iimm) & ~32'd1;
                    branch_target = PC + Bimm;

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