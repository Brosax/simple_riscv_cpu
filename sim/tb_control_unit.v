`timescale 1ns / 1ps

module tb_control_unit;

    // --- Inputs ---
    reg [6:0] opcode;

    // --- Outputs ---
    wire alu_src;
    wire [1:0] alu_op;
    wire mem_to_reg;
    wire reg_write;
    wire mem_read;
    wire mem_write;
    wire branch;
    wire jump;

    // --- Instantiate DUT ---
    control_unit uut (
        .opcode(opcode),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_to_reg(mem_to_reg),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jump(jump)
    );

    // --- Opcodes ---
    localparam OPCODE_R_TYPE       = 7'b0110011;
    localparam OPCODE_I_TYPE_ARITH = 7'b0010011;
    localparam OPCODE_I_TYPE_LOAD  = 7'b0000011;
    localparam OPCODE_S_TYPE       = 7'b0100011;
    localparam OPCODE_B_TYPE       = 7'b1100011;
    localparam OPCODE_JAL          = 7'b1101111;
    localparam OPCODE_JALR         = 7'b1100111;
    localparam OPCODE_LUI          = 7'b0110111;
    localparam OPCODE_AUIPC        = 7'b0010111;

    task check_control;
        input [6:0] op;
        input [8:0] expected_signals; // {alu_src, alu_op, mem_to_reg, reg_write, mem_read, mem_write, branch, jump}
        input [255:0] test_name;
        begin
            opcode = op;
            #1; // Settle
            if ({alu_src, alu_op, mem_to_reg, reg_write, mem_read, mem_write, branch, jump} === expected_signals) begin
                $display("PASS: %s", test_name);
            end else begin
                $display("FAIL: %s", test_name);
                $display("      Expected: %b", expected_signals);
                $display("      Got:      %b", {alu_src, alu_op, mem_to_reg, reg_write, mem_read, mem_write, branch, jump});
            end
        end
    endtask

    initial begin
        $display("--- Starting Control Unit Testbench ---");

        // Signals: {alu_src, alu_op, mem_to_reg, reg_write, mem_read, mem_write, branch, jump}
        check_control(OPCODE_R_TYPE,       9'b0_10_0_1_0_0_0_0, "R-Type");
        check_control(OPCODE_I_TYPE_ARITH, 9'b1_00_0_1_0_0_0_0, "I-Type-Arith");
        check_control(OPCODE_I_TYPE_LOAD,  9'b1_11_1_1_1_0_0_0, "I-Type-Load");
        check_control(OPCODE_S_TYPE,       9'b1_11_0_0_0_1_0_0, "S-Type");
        check_control(OPCODE_B_TYPE,       9'b0_01_0_0_0_0_1_0, "B-Type");
        check_control(OPCODE_JAL,          9'b0_00_0_1_0_0_0_1, "JAL");
        check_control(OPCODE_JALR,         9'b1_00_0_1_0_0_0_1, "JALR");
        check_control(OPCODE_LUI,          9'b1_11_0_1_0_0_0_0, "LUI");
        check_control(OPCODE_AUIPC,        9'b1_11_0_1_0_0_0_0, "AUIPC");

        $display("--- Control Unit Test Finished ---");
        $finish;
    end

endmodule
