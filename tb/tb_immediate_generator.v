`timescale 1ns / 1ps

module tb_immediate_generator;

    // --- Testbench Signals ---
    reg [31:0] instruction;
    wire [31:0] imm_extended;

    // --- Instantiate DUT ---
    immediate_generator uut (
        .instruction(instruction),
        .imm_extended(imm_extended)
    );

    task check_imm;
        input [31:0] inst;
        input [31:0] expected_imm;
        input [255:0] test_name;
        begin
            instruction = inst;
            #1; // Allow combinational logic to settle
            if (imm_extended === expected_imm)
                $display("PASS: %s", test_name);
            else
                $display("FAIL: %s -> Expected: %h, Got: %h", test_name, expected_imm, imm_extended);
        end
    endtask

    // --- Test Sequence ---
    initial begin
        $display("--- Starting Immediate Generator Testbench (Final Attempt) ---");

        // --- I-Type: addi x5, x10, -50 ---
        // imm = -50 (0xFFFFFFCE)
        check_imm(32'hFCE50293, -32'd50, "I-Type (addi, negative)");

        // --- S-Type: sw x5, 32(x10) ---
        // imm = 32 (0x20)
        check_imm(32'h02552023, 32'd32, "S-Type (sw, positive)");

        // --- B-Type: beq x1, x2, -8 ---
        // imm = -8 (0xFFFFFFF8)
        //check_imm(32'hFE2088E3, -32'd8, "B-Type (beq, negative)");
        check_imm(32'hFE208CE3, -32'd8, "B-Type (beq, negative)");//-8

        // --- U-Type: lui x5, 0xDEADB ---
        check_imm(32'hDEADB2B7, 32'hDEADB000, "U-Type (lui)");

        // --- J-Type: jal x1, -32 ---
        // imm = -32 (0xFFFFFFE0)
        check_imm(32'hFE1FF0EF, -32'd32, "J-Type (jal, negative)");

        $display("--- Immediate Generator Test Finished ---");
        $finish;
    end

endmodule
