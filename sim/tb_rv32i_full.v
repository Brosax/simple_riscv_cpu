`timescale 1ns / 1ps

module tb_rv32i_full;

    // --- Entradas del Core ---
    reg clk;
    reg rst;

    // --- Salidas/Entradas del Core ---
    wire timer_interrupt;
    wire [7:0] gpio_pins_tb;

    // --- Instanciación del Core ---
    riscv_core uut (
        .clk(clk),
        .rst(rst),
        .timer_interrupt(timer_interrupt),
        .gpio_pins(gpio_pins_tb)
    );

    // --- Generador de Reloj ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Reloj de 100MHz (periodo de 10ns)
    end

    // --- Variables de Test ---
    integer tests_passed = 0;
    integer tests_failed = 0;
    reg [31:0] expected_value;

    // --- Macro para verificar registros ---
    task check_reg;
        input [4:0] reg_addr;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            if (uut.reg_file.registers[reg_addr] === expected) begin
                $display("PASS: %s (x%0d = %h)", test_name, reg_addr, uut.reg_file.registers[reg_addr]);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s (x%0d -> expected: %h, got: %h)", test_name, reg_addr, expected, uut.reg_file.registers[reg_addr]);
                tests_failed = tests_failed + 1;
            end
        end
    endtask
    
    // --- Macro para verificar memoria ---
    task check_mem;
        input [11:2] mem_addr;
        input [31:0] expected;
        input [255:0] test_name;
        reg [31:0] read_value;
        begin
            read_value = {uut.data_mem.mem[mem_addr*4+3], uut.data_mem.mem[mem_addr*4+2], uut.data_mem.mem[mem_addr*4+1], uut.data_mem.mem[mem_addr*4]};
            if (read_value === expected) begin
                $display("PASS: %s (mem[%h] = %h)", test_name, mem_addr, read_value);
                tests_passed = tests_passed + 1;
            end else begin
                $display("FAIL: %s (mem[%h] -> expected: %h, got: %h)", test_name, mem_addr, expected, read_value);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // --- Secuencia de Test ---
    initial begin
        $dumpfile("tb_rv32i_full.vcd");
        $dumpvars(0, tb_rv32i_full);

        // 1. Aplicar pulso de Reset
        rst = 1;
        #20;
        rst = 0;
        #10; // Esperar un ciclo para que se ejecute la primera instrucción

        // --- Verificación ---
        // El testbench comprueba el resultado en el ciclo *después* de la ejecución de la instrucción.
        // Por eso, la comprobación para la instrucción en PC=0x00 se hace cuando PC=0x04.
        
        // Bucle principal de verificación
        while (uut.pc_current < 32'hcc) begin
            #10; // Avanzar al siguiente ciclo de reloj
            case (uut.pc_current)
                // 1. Setup
                32'h004: check_reg(1, 32'd10, "ADDI setup x1");
                32'h008: check_reg(2, -32'd20, "ADDI setup x2");
                // 2. I-Type
                32'h00c: check_reg(3, 32'd15, "ADDI");
                32'h010: check_reg(4, 32'd1, "SLTI");
                32'h014: check_reg(5, 32'd0, "SLTIU");
                32'h018: check_reg(6, 32'hfffff_f05, "XORI");
                32'h01c: check_reg(7, 32'hfffff_f0f, "ORI");
                32'h020: check_reg(8, 32'h00A, "ANDI");
                32'h024: check_reg(9, 32'd40, "SLLI");
                32'h028: check_reg(10, 32'd2, "SRLI");
                32'h02c: check_reg(11, -32'd5, "SRAI");
                // 3. R-Type
                32'h030: check_reg(12, -32'd10, "ADD");
                32'h034: check_reg(13, 32'd30, "SUB");
                32'h038: check_reg(14, 32'd1, "SLT");
                32'h03c: check_reg(15, 32'd0, "SLTU");
                32'h040: check_reg(16, 10 ^ -20, "XOR");
                32'h044: check_reg(17, 10 | -20, "OR");
                32'h048: check_reg(18, 10 & -20, "AND");
                32'h04c: check_reg(19, 32'h00002800, "SLL"); // FIX: rd=19, val=10<<10=0x2800
                32'h050: check_reg(20, 10 >>> 10, "SRL");
                32'h054: check_reg(21, -20 >>> 10, "SRA");
                // 4. Memory Store
                32'h058: check_mem(32'hfffffff0, -32'd10, "SW");
                // 32'h05c: check_mem(1, 32'h0000001e, "SH"); // mem[4]
                // 32'h060: check_mem(1, 32'h0a00001e, "SB"); // mem[6] is part of mem[4] word
                // 5. Memory Load
                32'h064: check_reg(22, -32'd10, "LW");
                32'h068: check_reg(23, 32'd30, "LH");
                32'h06c: check_reg(24, 32'd30, "LHU");
                32'h070: check_reg(25, 32'd10, "LB");
                32'h074: check_reg(26, 32'd10, "LBU");
                // 6. LUI/AUIPC
                32'h078: check_reg(26, 32'habcde000, "LUI"); // FIX: rd=26
                32'h07c: check_reg(28, 32'h00000078, "AUIPC");
                // 7. Branches
                32'h080: check_reg(29, 5, "ADDI setup x29");
                32'h084: check_reg(30, 5, "ADDI setup x30");
                // 8. Jumps
                32'h0c4: check_reg(30, 32'h000000c0, "JAL"); // FIX: rd=30
                32'h0c8: #10; // Let JALR execute
            endcase
        end

        #20; // Wait for final instructions
        
        // Final check for JALR return
        if (uut.pc_current === 32'hc0) begin
             $display("PASS: JALR returned correctly to PC=%h", uut.pc_current);
             tests_passed = tests_passed + 1;
        end else begin
             $display("FAIL: JALR return (expected: %h, got: %h)", 32'hc0, uut.pc_current);
             tests_failed = tests_failed + 1;
        end
        
        // Final check for register modified inside JAL target
        check_reg(1, 100, "JAL target ADDI");


        // --- Resumen del Test ---
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
