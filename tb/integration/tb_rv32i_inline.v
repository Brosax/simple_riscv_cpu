`timescale 1ns / 1ps
`define SIMULATION

// Inline integration test: hardcoded program exercises ADD, SUB, SLT, SLL,
// ADDI, SLTI, SW, LW, BNE, AUIPC, JALR.
// All PC comparisons use the 0x80000000 base address.

module tb_rv32i_inline;

    reg clk;
    reg rst;
    wire timer_interrupt;
    wire [7:0] gpio_pins_tb;

    riscv_core uut (
        .clk(clk),
        .rst(rst),
        .timer_interrupt(timer_interrupt),
        .gpio_pins(gpio_pins_tb),
        .ext_interrupt(1'b0),
        .debug_stall(1'b0),
        .debug_reg_addr(5'b0),
        .debug_reg_read(1'b0),
        .debug_reg_write(1'b0),
        .debug_reg_wdata(32'b0),
        .debug_mem_read(1'b0),
        .debug_mem_addr(32'b0),
        .debug_mem_write(1'b0),
        .debug_mem_wdata(32'b0),
        .debug_mem_wstrb(4'b0)
    );

    // Initialize data memory to zero and load test program
    integer j;
    initial begin
        #1; // Wait for $readmemh to finish
        // --- SETUP ---
        uut.instr_mem.mem[0]  = 32'h00A00113; // 0x80000000: addi x2, x0, 10
        uut.instr_mem.mem[1]  = 32'hFEC00193; // 0x80000004: addi x3, x0, -20
        // --- R-TYPE ---
        uut.instr_mem.mem[2]  = 32'h00310233; // 0x80000008: add  x4, x2, x3
        uut.instr_mem.mem[3]  = 32'h403102B3; // 0x8000000C: sub  x5, x2, x3
        uut.instr_mem.mem[4]  = 32'h0021A333; // 0x80000010: slt  x6, x3, x2  (-20 < 10 = 1)
        uut.instr_mem.mem[5]  = 32'h002193B3; // 0x80000014: sll  x7, x3, x2  (0xFFFFFFEC << 10 = 0xFFFFB000)
        // --- I-TYPE ---
        uut.instr_mem.mem[6]  = 32'h00F10413; // 0x80000018: addi x8, x2, 15
        uut.instr_mem.mem[7]  = 32'hFFB1A493; // 0x8000001C: slti x9, x3, -5  (-20 < -5 = 1)
        // --- MEMORY ---
        uut.instr_mem.mem[8]  = 32'h00400893; // 0x80000020: addi x17, x0, 4
        uut.instr_mem.mem[9]  = 32'h0058A223; // 0x80000024: sw   x5, 4(x17)  -> mem[8] = 30
        uut.instr_mem.mem[10] = 32'h0088A383; // 0x80000028: lw   x7, 8(x17)  -> x7 = mem[12] = 0
        uut.instr_mem.mem[11] = 32'h0048A303; // 0x8000002C: lw   x6, 4(x17)  -> x6 = mem[8] = 30
        // --- BRANCH ---
        // bne x3, x2, +24 -> target = 0x80000030 + 24 = 0x80000048 (mem[18])
        uut.instr_mem.mem[12] = 32'h00219C63; // 0x80000030: bne  x3, x2, +24
        uut.instr_mem.mem[13] = 32'hDEADBEEF; // 0x80000034: Should be skipped
        // mem[14..17] = NOP (0x00000013)
        // --- JUMP TARGET ---
        uut.instr_mem.mem[18] = 32'h00100413; // 0x80000048: addi x8, x0, 1
        // --- AUIPC + ADDI + JALR ---
        uut.instr_mem.mem[19] = 32'h00000517; // 0x8000004C: auipc x10, 0  -> x10 = 0x8000004C
        uut.instr_mem.mem[20] = 32'hFB450513; // 0x80000050: addi  x10, x10, -76 -> x10 = 0x80000000
        uut.instr_mem.mem[21] = 32'h000500E7; // 0x80000054: jalr  x1, x10, 0 -> jump to 0x80000000
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer tests_passed = 0;
    integer tests_failed = 0;

    task check_r_type;
        input [4:0]  rd, rs1, rs2;
        input [31:0] expected_val;
        input [255:0] test_name;
        begin
            if (uut.reg_file.registers[rd] === expected_val) begin
                $display("PASS: %s (x%0d = %h)", test_name, rd, uut.reg_file.registers[rd]);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s (x%0d -> expected %h, got %h)",
                          test_name, rd, expected_val, uut.reg_file.registers[rd]);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    task check_i_type_arith;
        input [4:0]  rd, rs1;
        input signed [31:0] imm;
        input [31:0] expected_val;
        input [255:0] test_name;
        begin
            if (uut.reg_file.registers[rd] === expected_val) begin
                $display("PASS: %s (x%0d = %h)", test_name, rd, expected_val);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s (x%0d -> expected %h, got %h)",
                          test_name, rd, expected_val, uut.reg_file.registers[rd]);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    task check_reg;
        input [4:0] reg_addr;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            if (uut.reg_file.registers[reg_addr] === expected) begin
                $display("PASS: %s (x%0d = %h)", test_name, reg_addr, expected);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s (x%0d -> expected %h, got %h)",
                          test_name, reg_addr, expected, uut.reg_file.registers[reg_addr]);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    task check_mem;
        input [11:2] mem_addr;
        input [31:0] expected;
        input [255:0] test_name;
        reg [31:0] read_value;
        begin
            read_value = {uut.data_mem.mem_b3[mem_addr],
                          uut.data_mem.mem_b2[mem_addr],
                          uut.data_mem.mem_b1[mem_addr],
                          uut.data_mem.mem_b0[mem_addr]};
            if (read_value === expected) begin
                $display("PASS: %s (mem[%h] = %h)", test_name, mem_addr*4, expected);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s (mem[%h] -> expected %h, got %h)",
                          test_name, mem_addr*4, expected, read_value);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    task wait_for_done;
        begin
            @(posedge clk);
            while (!uut.instruction_done) @(posedge clk);
            // wait for the negative edge so we check register states AFTER they are written
            @(negedge clk);
        end
    endtask

    initial begin
        rst = 1; #20; rst = 0;

        wait_for_done(); check_i_type_arith(2,  0,  10,  32'd10,       "SETUP: ADDI x2=10");
        wait_for_done(); check_i_type_arith(3,  0, -20,  32'hFFFFFFEC, "SETUP: ADDI x3=-20");
        wait_for_done(); check_r_type(4, 2, 3, 32'hFFFFFFF6, "ADD x4=x2+x3");
        wait_for_done(); check_r_type(5, 2, 3, 32'd30,       "SUB x5=x2-x3");
        wait_for_done(); check_r_type(6, 3, 2, 32'd1,        "SLT x6=(x3<x2)=(-20<10)=1");
        wait_for_done(); check_r_type(7, 3, 2, 32'hFFFFB000, "SLL x7=x3<<x2=0xFFFFEC<<10");
        wait_for_done(); check_i_type_arith(8,  2, 15,  32'd25, "ADDI x8=25");
        wait_for_done(); check_i_type_arith(9,  3, -5,  32'd1,  "SLTI x9=(-20<-5)=1");
        wait_for_done(); check_i_type_arith(17, 0,  4,  32'd4,  "MEMORY: ADDI x17=4");
        // SW (mem[9]) executes naturally in the next clock edge
        wait_for_done(); check_mem(2, 32'd30, "MEMORY: SW mem[8]=30");
        wait_for_done(); check_reg(7, 32'd0,  "MEMORY: LW x7=mem[12]=0");
        wait_for_done(); check_reg(6, 32'd30, "MEMORY: LW x6=mem[8]=30");

        // BNE
        wait_for_done();
        if (uut.pc_current !== 32'h80000030) $display("FAIL: PC before BNE (expected 0x80000030, got %h)", uut.pc_current);
        else $display("PASS: PC before BNE");
        
        wait_for_done();
        if (uut.pc_current !== 32'h80000048) $display("FAIL: BNE (PC=%h, expected 0x80000048)", uut.pc_current);
        else $display("PASS: BNE (PC updated to 0x80000048)");

        check_reg(8, 32'd1,  "BRANCH: ADDI x8=1 at target");
        wait_for_done(); check_reg(10, 32'h8000004C, "JUMP: AUIPC x10=0x8000004C");
        wait_for_done(); check_reg(10, 32'h80000000, "JUMP: ADDI x10=0x80000000");

        wait_for_done();
        if (uut.pc_current !== 32'h80000000) $display("FAIL: JALR did not jump to 0x80000000");
        else $display("PASS: JALR jumped to 0x80000000");
        check_reg(1, 32'h80000058, "JUMP: JALR link x1=0x80000058");

        $display("\n-------------------");
        $display("TEST SUMMARY");
        $display("Passed: %0d  Failed: %0d", tests_passed, tests_failed);
        $display("-------------------");
        if (tests_failed == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
