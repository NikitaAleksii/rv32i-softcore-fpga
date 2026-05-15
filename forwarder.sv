module forwarder(
    input logic [31:0] d_instruction,
    input logic [31:0] e_instruction,
    input logic [31:0] m_instruction,
    input logic [31:0] w_instruction,
    input logic [31:0] e_reg_write_data,
    input logic [31:0] m_reg_write_data,
    input logic [31:0] w_reg_write_data,
    input logic [31:0] w_load_data,
    input logic [31:0] d_rs1_data,
    input logic [31:0] d_rs2_data,
    input logic [31:0] e_rs1_data,
    input logic [31:0] e_rs2_data,
    input logic [31:0] d_Iimm,
    input logic [31:0] d_Simm,
    output logic conflict_de,
    output logic conflict_dm,
    output logic [31:0] d_forward_jumpr_target,
    output logic [31:0] d_forward_adjusted_load_addr,
    output logic [31:0] d_forward_adjusted_store_addr,
    output logic [31:0] d_forward_rs1_data,
    output logic [31:0] d_forward_rs2_data,
    output logic [31:0] e_forward_rs1_data,
    output logic [31:0] e_forward_rs2_data
);
    logic w_is_load;
    assign w_is_load = (w_instruction[6:0] == 7'b0000011);

    logic [31:0] w_forward_data;
    assign w_forward_data = w_is_load ? w_load_data : w_reg_write_data;

    // DE data hazard detector 
    conflict_checker de_register_checker_inst (
        .R_instruction(d_instruction),
        .W_instruction(e_instruction),
        .conflict(conflict_de)
    );

    // DM data hazard detector 
    conflict_checker dm_register_checker_inst (
        .R_instruction(d_instruction),
        .W_instruction(m_instruction),
        .conflict(conflict_dm)
    );

    // DW data hazard detector 
    logic conflict_dw;
    conflict_checker dw_register_checker_inst (
        .R_instruction(d_instruction),
        .W_instruction(w_instruction),
        .conflict(conflict_dw)
    );

    // EM data hazard detector 
    logic conflict_em;
    conflict_checker em_register_checker_inst (
        .R_instruction(e_instruction),
        .W_instruction(m_instruction),
        .conflict(conflict_em)
    );

    // EW data hazard detector 
    logic conflict_ew;
    conflict_checker ew_register_checker_inst (
        .R_instruction(e_instruction),
        .W_instruction(w_instruction),
        .conflict(conflict_ew)
    );

    always_comb begin
        // D stage forwarding with rs1
        if (conflict_de && d_instruction[19:15] == e_instruction[11:7]) begin
            // Load-Use hazard
            d_forward_jumpr_target = (e_reg_write_data + d_Iimm) & ~32'd1;
            d_forward_adjusted_load_addr = e_reg_write_data + d_Iimm;
            d_forward_adjusted_store_addr = e_reg_write_data + d_Simm;
            d_forward_rs1_data = e_reg_write_data;
        end else if (conflict_dm && d_instruction[19:15] == m_instruction[11:7]) begin
            // Load-Use hazard if M is a load
            // Otherwise, RAW hazard 
            d_forward_jumpr_target = (m_reg_write_data + d_Iimm) & ~32'd1;
            d_forward_adjusted_load_addr = m_reg_write_data + d_Iimm;
            d_forward_adjusted_store_addr = m_reg_write_data + d_Simm;
            d_forward_rs1_data = m_reg_write_data;
        end else if (conflict_dw && d_instruction[19:15] == w_instruction[11:7]) begin
            // RAW (Read After Write) hazard
            d_forward_jumpr_target = (w_forward_data + d_Iimm) & ~32'd1;
            d_forward_adjusted_load_addr = w_forward_data + d_Iimm;
            d_forward_adjusted_store_addr = w_forward_data + d_Simm;
            d_forward_rs1_data = w_forward_data;
        end else begin
            // No hazard
            d_forward_jumpr_target = (d_rs1_data + d_Iimm) & ~32'd1;
            d_forward_adjusted_load_addr = d_rs1_data + d_Iimm;
            d_forward_adjusted_store_addr = d_rs1_data + d_Simm;
            d_forward_rs1_data = d_rs1_data;
        end

        // D stage forwarding with rs2
        if (conflict_de && d_instruction[24:20] == e_instruction[11:7]) begin
            d_forward_rs2_data = e_reg_write_data;
        end else if (conflict_dm && d_instruction[24:20] == m_instruction[11:7]) begin
            d_forward_rs2_data = m_reg_write_data;
        end else if (conflict_dw && d_instruction[24:20] == w_instruction[11:7]) begin
            d_forward_rs2_data = w_forward_data;
        end else begin
            d_forward_rs2_data = d_rs2_data;
        end

        // E stage M/W forwarding (rs1)
        if (conflict_em && e_instruction[19:15] == m_instruction[11:7]) begin
            // RAW hazard
            e_forward_rs1_data = m_reg_write_data;
        end else if (conflict_ew && e_instruction[19:15] == w_instruction[11:7]) begin
            // RAW hazard
            e_forward_rs1_data = w_forward_data;
        end else begin
            e_forward_rs1_data = e_rs1_data;
        end

        // E stage M/W forwarding (rs2)
        if (conflict_em && e_instruction[24:20] == m_instruction[11:7]) begin
            e_forward_rs2_data = m_reg_write_data;
        end else if (conflict_ew && e_instruction[24:20] == w_instruction[11:7]) begin
            e_forward_rs2_data = w_forward_data;
        end else begin
            e_forward_rs2_data = e_rs2_data;
        end
    end   
endmodule