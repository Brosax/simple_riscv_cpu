`timescale 1ns / 1ps

module tb_golden_suite;

    // --- Core的输入和输出 ---
    reg clk;
    reg rst;
    wire timer_interrupt;
    wire [7:0] gpio_pins_tb;

    // --- 实例化CPU核 ---
    riscv_core uut (
        .clk(clk),
        .rst(rst),
        .timer_interrupt(timer_interrupt),
        .gpio_pins(gpio_pins_tb)
    );

    // --- 使用initial块将测试程序加载到指令存储器中 ---
    // 假设您的CPU核的指令存储器路径是 uut.instr_mem.mem
    initial begin
        // --- SETUP ---
        uut.instr_mem.mem[0] = 32'h00A00113; // 0x000: addi x2, x0, 10
        uut.instr_mem.mem[1] = 32'hFEC00193; // 0x004: addi x3, x0, -20
        // --- R-TYPE ---
        uut.instr_mem.mem[2] = 32'h00310233; // 0x008: add  x4, x2, x3
        uut.instr_mem.mem[3] = 32'h403102B3; // 0x00C: sub  x5, x2, x3
        uut.instr_mem.mem[4] = 32'h00312333; // 0x010: slt  x6, x2, x3
        uut.instr_mem.mem[5] = 32'h00A1F3B3; // 0x014: sll  x7, x3, x2
        // --- I-TYPE ---
        uut.instr_mem.mem[6] = 32'h00F10413; // 0x018: addi x8, x2, 15
        uut.instr_mem.mem[7] = 32'hFFB1A493; // 0x01C: slti x9, x3, -5
        // --- MEMORY ---
        uut.instr_mem.mem[8] = 32'h00400893; // 0x020: addi x17, x0, 4
        uut.instr_mem.mem[9] = 32'h0058A223; // 0x024: sw   x5, 4(x17)  ; addr = 4+4=8
        uut.instr_mem.mem[10] = 32'h0088A383; // 0x028: lw   x7, 8(x17)  ; addr = 8+4=12, should be 0
        uut.instr_mem.mem[11] = 32'h0048A303; // 0x02C: lw   x6, 4(x17)  ; addr = 4+4=8, should be 30
        // --- BRANCH ---
        uut.instr_mem.mem[12] = 32'hFE218CE3; // 0x030: bne  x3, x2, 24 ; target = 0x030 + 24 = 0x048
        uut.instr_mem.mem[13] = 32'hDEADBEEF; // 0x034: Should be skipped
        // ... (Memory up to 0x044 is empty)
        // --- JUMP TARGET ---
        uut.instr_mem.mem[18] = 32'h00100413; // 0x048: addi x8, x0, 1
        // --- JUMP ---
        uut.instr_mem.mem[19] = 32'h00000517; // 0x04C: auipc x10, 0
        uut.instr_mem.mem[20] = 32'hFB450513; // 0x050: addi x10, x10, -76
        uut.instr_mem.mem[21] = 32'h000500E7; // 0x054: jalr x1, x10, 0
    end

    // --- 时钟生成器 ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz 时钟
    end

    // --- 测试变量和任务 ---
    integer tests_passed = 0;
    integer tests_failed = 0;

    // 任务: 验证 R-Type 指令
    task check_r_type;
        input [4:0]  rd, rs1, rs2;
        input [31:0] expected_val;
        input [255:0] test_name;
        begin
            $display("--------------------------------------------------");
            $display("Test: %s", test_name);
            $display("      Instruction: %s x%0d, x%0d, x%0d", test_name, rd, rs1, rs2);
            $display("      Context: rs1(x%0d) = %d (%h) | rs2(x%0d) = %d (%h)", 
                      rs1, uut.reg_file.registers[rs1], uut.reg_file.registers[rs1],
                      rs2, uut.reg_file.registers[rs2], uut.reg_file.registers[rs2]);
            if (uut.reg_file.registers[rd] === expected_val) begin
                $display("Result: PASS (rd(x%0d) = %h)", rd, uut.reg_file.registers[rd]);
                tests_passed = tests_passed + 1;
            end else begin
                $display("Result: FAIL (rd(x%0d) -> expected: %h, got: %h)", 
                          rd, expected_val, uut.reg_file.registers[rd]);
                tests_failed = tests_failed + 1;
            end
            $display("--------------------------------------------------");
        end
    endtask

    // 任务: 验证 I-Type 算术指令
    task check_i_type_arith;
        input [4:0]  rd, rs1;
        input signed [31:0] imm;
        input [31:0] expected_val;
        input [255:0] test_name;
        begin
            $display("--------------------------------------------------");
            $display("Test: %s", test_name);
            $display("      Instruction: %s x%0d, x%0d, %d", test_name, rd, rs1, imm);
            $display("      Context: rs1(x%0d) = %d (%h) | imm = %d (%h)", 
                      rs1, uut.reg_file.registers[rs1], uut.reg_file.registers[rs1], imm, imm);
            if (uut.reg_file.registers[rd] === expected_val) begin
                $display("Result: PASS (rd(x%0d) = %h)", rd, uut.reg_file.registers[rd]);
                tests_passed = tests_passed + 1;
            end else begin
                $display("Result: FAIL (rd(x%0d) -> expected: %h, got: %h)", 
                          rd, expected_val, uut.reg_file.registers[rd]);
                tests_failed = tests_failed + 1;
            end
            $display("--------------------------------------------------");
        end
    endtask

    // 任务: 通用寄存器检查 (用于LUI, AUIPC等)
    task check_reg;
        input [4:0] reg_addr;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            if (uut.reg_file.registers[reg_addr] === expected) begin
                $display("PASS: %s (x%0d = %h)", test_name, reg_addr, expected);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s (x%0d -> expected: %h, got: %h)", test_name, reg_addr, expected, uut.reg_file.registers[reg_addr]);
                tests_failed = tests_failed + 1;
            end
        end
    endtask
    
    // 任务: 内存检查
    task check_mem;
        input [11:2] mem_addr;
        input [31:0] expected;
        input [255:0] test_name;
        reg [31:0] read_value;
        begin
            read_value = {uut.data_mem.mem[mem_addr*4+3], uut.data_mem.mem[mem_addr*4+2], uut.data_mem.mem[mem_addr*4+1], uut.data_mem.mem[mem_addr*4]};
            if (read_value === expected) begin
                $display("PASS: %s (mem[%h] = %h)", test_name, mem_addr*4, expected);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s (mem[%h] -> expected: %h, got: %h)", test_name, mem_addr*4, expected, read_value);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // --- 主测试序列 ---
    initial begin
        $dumpfile("tb_golden_suite.vcd");
        $dumpvars(0, tb_golden_suite);

        // 1. 复位
        rst = 1;
        #20;
        rst = 0;
        
        // --- 逐周期验证 ---
        #10; // 执行 PC=0x000: addi x2, x0, 10
        check_i_type_arith(2, 0, 10, 10, "SETUP: ADDI");

        #10; // 执行 PC=0x004: addi x3, x0, -20
        check_i_type_arith(3, 0, -20, -20, "SETUP: ADDI");
        
        #10; // 执行 PC=0x008: add x4, x2, x3
        check_r_type(4, 2, 3, -10, "ADD");

        #10; // 执行 PC=0x00C: sub x5, x2, x3
        check_r_type(5, 2, 3, 30, "SUB");
        
        #10; // 执行 PC=0x010: slt x6, x2, x3
        check_r_type(6, 2, 3, 1, "SLT"); // -20 < 10 is true

        #10; // 执行 PC=0x014: sll x7, x3, x2
        check_r_type(7, 3, 2, 32'hffffe800, "SLL");

        #10; // 执行 PC=0x018: addi x8, x2, 15
        check_i_type_arith(8, 2, 15, 25, "ADDI");

        #10; // 执行 PC=0x01C: slti x9, x3, -5
        check_i_type_arith(9, 3, -5, 1, "SLTI"); // -20 < -5 is true

        #10; // 执行 PC=0x020: addi x17, x0, 4
        check_i_type_arith(17, 0, 4, 4, "MEMORY: ADDI");
        
        #10; // 执行 PC=0x024: sw x5, 4(x17)
        // SW不修改寄存器, 在下一个周期检查内存
        
        #10; // 执行 PC=0x028: lw x7, 8(x17)
        check_mem(2, 30, "MEMORY: SW check"); // 检查地址 2*4=8 的内存
        
        #10; // 执行 PC=0x02C: lw x6, 4(x17)
        check_reg(7, 0, "MEMORY: LW (from addr 12)"); 
        
        #10; // 执行 PC=0x030: bne x3, x2, 24
        check_reg(6, 30, "MEMORY: LW (from addr 8)");
        
        #10; // bne在0x030执行后, PC应跳转到0x048
        if (uut.pc_current === 32'h048) begin
            $display("PASS: BNE branch taken correctly");
            tests_passed = tests_passed + 1;
        end else begin
            $display("FAIL: BNE branch not taken (PC is %h, expected 048h)", uut.pc_current);
            tests_failed = tests_failed + 1;
        end
        
        #10; // 执行 PC=0x048: addi x8, x0, 1
        check_i_type_arith(8, 0, 1, 1, "BRANCH: Landed at target");

        #10; // 执行 PC=0x04C: auipc x10, 0
        check_reg(10, 32'h0000004C, "JUMP: AUIPC");
        
        #10; // 执行 PC=0x050: addi x10, x10, -76
        check_i_type_arith(10, 10, -76, 0, "JUMP: ADDI to calc target");
        
        #10; // 执行 PC=0x054: jalr x1, x10, 0
        // JALR执行, PC将跳转到0x000

        #10; // PC现在应为 0x000
        if (uut.pc_current === 32'h000) begin
            $display("PASS: JALR jump taken correctly");
            tests_passed = tests_passed + 1;
        end else begin
            $display("FAIL: JALR jump not taken (PC is %h, expected 000h)", uut.pc_current);
            tests_failed = tests_failed + 1;
        end
        check_reg(1, 32'h00000058, "JUMP: JALR link register x1");

        // --- 测试总结 ---
        $display("\n-------------------");
        $display("TEST SUMMARY");
        $display("Passed: %0d", tests_passed);
        $display("Failed: %0d", tests_failed);
        $display("-------------------");
        if (tests_failed == 0) begin
            $display("ALL TESTS PASSED SUCCESSFULLY!");
        end else begin
            $display("SOME TESTS FAILED.");
        end

        $finish;
    end

endmodule