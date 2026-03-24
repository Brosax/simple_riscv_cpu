`timescale 1ns / 1ps

module tb_pc_register;

    // --- Testbench Signals ---
    reg clk;
    reg rst;
    reg [31:0] pc_in;
    wire [31:0] pc_out;

    // --- Instantiate DUT ---
    pc_register uut (
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    // --- Clock Generation ---
    always #5 clk = ~clk;

    // --- Test Sequence ---
    initial begin
        $display("--- Starting PC Register Testbench ---");
        clk = 0;
        rst = 1; // Assert reset
        pc_in = 32'h0;

        #10; // Wait for a bit

        if (pc_out === 32'h80000000) begin
            $display("PASS: PC is correctly initialized to 0x80000000 on reset.");
        end else begin
            $display("FAIL: PC is %h on reset, expected 0x80000000.", pc_out);
        end

        rst = 0; // De-assert reset
        #5; // Wait for posedge clk

        // Test loading a new value
        pc_in = 32'h80000004;
        #10; // Wait for next posedge clk
        if (pc_out === 32'h80000004) begin
            $display("PASS: PC correctly loaded value 0x80000004.");
        end else begin
            $display("FAIL: PC is %h, expected 0x80000004.", pc_out);
        end

        // Test loading another value
        pc_in = 32'hCAFEBABE;
        #10; // Wait for next posedge clk
        if (pc_out === 32'hCAFEBABE) begin
            $display("PASS: PC correctly loaded value 0xCAFEBABE.");
        end else begin
            $display("FAIL: PC is %h, expected 0xCAFEBABE.", pc_out);
        end

        $display("--- PC Register Test Finished ---");
        $finish;
    end

endmodule
