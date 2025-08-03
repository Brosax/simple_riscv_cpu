`timescale 1ns / 1ps

module tb_alu;

    // --- Testbench内部信号 ---
    reg  [31:0] tb_operand1;
    reg  [31:0] tb_operand2;
    reg  [3:0]  tb_alu_control;

    wire [31:0] tb_result;
    wire        tb_zero;

    integer tests_passed = 0;
    integer tests_failed = 0;

    // --- 实例化待测模块 (DUT: Design Under Test) ---
    alu uut (
        .operand1(tb_operand1),
        .operand2(tb_operand2),
        .alu_control(tb_alu_control),
        .result(tb_result),
        .zero(tb_zero)
    );

    // --- ALU操作码定义 (与您的alu.v和control_unit.v保持一致) ---
    localparam ALU_AND  = 4'b0000;
    localparam ALU_OR   = 4'b0001;
    localparam ALU_ADD  = 4'b0010;
    localparam ALU_SLL  = 4'b0011;
    localparam ALU_SRL  = 4'b0100;
    localparam ALU_SRA  = 4'b0101;
    localparam ALU_SUB  = 4'b0110;
    localparam ALU_SLT  = 4'b0111;
    localparam ALU_SLTU = 4'b1000;
    localparam ALU_XOR  = 4'b1001;

    // --- 自动化检查任务 ---
    task check_alu;
        input [31:0] op1, op2;
        input [3:0]  ctrl;
        input [31:0] expected_result;
        input        expected_zero;
        input [255:0] test_name;
        begin
            // 1. 应用激励
            tb_operand1 = op1;
            tb_operand2 = op2;
            tb_alu_control = ctrl;
            
            #1; // 等待1ns，让组合逻辑传播和稳定

            // 2. 检查结果
            if (tb_result === expected_result && tb_zero === expected_zero) begin
                $display("PASS: %s", test_name);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s", test_name);
                $display("      Inputs: op1=%h, op2=%h, ctrl=%b", op1, op2, ctrl);
                $display("      Result -> Expected: %h, Got: %h", expected_result, tb_result);
                $display("      Zero   -> Expected: %b, Got: %b", expected_zero, tb_zero);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // --- 主要测试序列 ---
    initial begin
        $dumpfile("alu_waves.vcd"); // 设置输出的波形文件名
        $dumpvars(0, tb_alu);       // 指示仿真器记录tb_alu模块下所有信号的变化
        $display("--- Starting ALU Testbench ---");

        // --- ADD Tests ---
        check_alu(10, 20, ALU_ADD, 30, 0, "ADD: 10 + 20");
        check_alu(32'hFFFFFFFF, 1, ALU_ADD, 0, 1, "ADD: -1 + 1 (tests zero flag)");
        
        // --- SUB Tests ---
        check_alu(10, 20, ALU_SUB, -10, 0, "SUB: 10 - 20");
        check_alu(50, 50, ALU_SUB, 0, 1, "SUB: 50 - 50 (tests zero flag)");
        
        // --- Logical Tests ---
        check_alu(32'hF0F0F0F0, 32'h0F0F0F0F, ALU_AND, 32'h00000000, 1, "AND");
        check_alu(32'hF0F0F0F0, 32'h0F0F0F0F, ALU_OR,  32'hFFFFFFFF, 0, "OR");
        check_alu(32'hF0F0F0F0, 32'h0F0F0F0F, ALU_XOR, 32'hFFFFFFFF, 0, "XOR");

        // --- Shift Tests ---
        check_alu(32'h0000000A, 2, ALU_SLL, 32'h00000028, 0, "SLL: 10 << 2");
        check_alu(32'hFFFFFFF6, 2, ALU_SRL, 32'h3FFFFFFD, 0, "SRL: -10 >> 2 (logical)");
        check_alu(32'hFFFFFFF6, 2, ALU_SRA, 32'hFFFFFFFD, 0, "SRA: -10 >>> 2 (arithmetic)");

        // --- Comparison Tests (SLT - Signed) ---
        check_alu(10, 20, ALU_SLT, 1, 0, "SLT: 10 < 20 (signed)");
        check_alu(20, 10, ALU_SLT, 0, 1, "SLT: 20 < 10 (signed)");
        check_alu(-10, 10, ALU_SLT, 1, 0, "SLT: -10 < 10 (signed)");
        check_alu(10, -10, ALU_SLT, 0, 1, "SLT: 10 < -10 (signed)");

        // --- Comparison Tests (SLTU - Unsigned) ---
        check_alu(10, 20, ALU_SLTU, 1, 0, "SLTU: 10 < 20 (unsigned)");
        check_alu(20, 10, ALU_SLTU, 0, 1, "SLTU: 20 < 10 (unsigned)");
        // Crucial test: -10 is a very large positive number in unsigned
        check_alu(10, -10, ALU_SLTU, 1, 0, "SLTU: 10 < -10 (unsigned)"); 
        check_alu(-10, 10, ALU_SLTU, 0, 1, "SLTU: -10 < 10 (unsigned)");

        // --- Resumen del Test ---
        $display("\n-------------------");
        $display("TEST SUMMARY");
        $display("Passed: %0d", tests_passed);
        $display("Failed: %0d", tests_failed);
        $display("-------------------");

        if (tests_failed == 0) begin
            $display("ALL ALU TESTS PASSED SUCCESSFULLY!");
        end else begin
            $display("SOME ALU TESTS FAILED.");
        end

        $finish;
    end

endmodule