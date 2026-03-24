`timescale 1ns / 1ps

module tb_alu_control_unit;

    // --- Inputs ---
    reg [1:0] alu_op;
    reg [2:0] funct3;
    reg funct7_bit5;

    // --- Output ---
    wire [3:0] alu_control;

    // --- Instantiate DUT ---
    alu_control_unit uut (
        .alu_op(alu_op),
        .funct3(funct3),
        .funct7_bit5(funct7_bit5),
        .alu_control(alu_control)
    );

    // --- Localparams for ALU operations (from alu.v) ---
    localparam ALU_ADD  = 4'b0010;
    localparam ALU_SUB  = 4'b0110;
    localparam ALU_SLL  = 4'b0011;
    localparam ALU_SLT  = 4'b0111;
    localparam ALU_SLTU = 4'b1000;
    localparam ALU_XOR  = 4'b1001;
    localparam ALU_SRL  = 4'b0100;
    localparam ALU_SRA  = 4'b0101;
    localparam ALU_OR   = 4'b0001;
    localparam ALU_AND  = 4'b0000;

    task check_control;
        input [1:0] op;
        input [2:0] f3;
        input f7b5;
        input [3:0] expected_ctrl;
        input [255:0] test_name;
        begin
            alu_op = op;
            funct3 = f3;
            funct7_bit5 = f7b5;
            #1; // Let logic settle
            if (alu_control === expected_ctrl)
                $display("PASS: %s", test_name);
            else
                $display("FAIL: %s -> Expected: %b, Got: %b", test_name, expected_ctrl, alu_control);
        end
    endtask

    initial begin
        $display("--- Starting ALU Control Unit Testbench ---");

        // --- Test R-Type (alu_op = 2'b10) ---
        check_control(2'b10, 3'b000, 1'b0, ALU_ADD, "R-Type ADD");
        check_control(2'b10, 3'b000, 1'b1, ALU_SUB, "R-Type SUB");
        check_control(2'b10, 3'b001, 1'b0, ALU_SLL, "R-Type SLL");
        check_control(2'b10, 3'b101, 1'b0, ALU_SRL, "R-Type SRL");
        check_control(2'b10, 3'b101, 1'b1, ALU_SRA, "R-Type SRA");

        // --- Test I-Type (alu_op = 2'b00) ---
        check_control(2'b00, 3'b000, 1'b0, ALU_ADD, "I-Type ADDI");
        check_control(2'b00, 3'b010, 1'b0, ALU_SLT, "I-Type SLTI");
        check_control(2'b00, 3'b111, 1'b0, ALU_AND, "I-Type ANDI");

        // --- Test B-Type (alu_op = 2'b01) ---
        check_control(2'b01, 3'b000, 1'b0, ALU_SUB, "B-Type (BEQ)"); // funct3 doesn't matter for B-type
        check_control(2'b01, 3'b101, 1'b1, ALU_SUB, "B-Type (BGE)");

        // --- Test Load/Store/U-Type (alu_op = 2'b11) ---
        check_control(2'b11, 3'b010, 1'b0, ALU_ADD, "Load/Store/U-Type (LW)"); // funct3 doesn't matter

        $display("--- ALU Control Unit Test Finished ---");
        $finish;
    end

endmodule
