`timescale 1ns / 1ps

module tb_alu_sll;

    reg [31:0] operand1;
    reg [31:0] operand2;
    reg [3:0] alu_control;
    wire [31:0] result;
    wire zero;

    alu uut (
        .operand1(operand1),
        .operand2(operand2),
        .alu_control(alu_control),
        .result(result),
        .zero(zero)
    );

    initial begin
        operand1 = 32'hffffffec; // -20
        operand2 = 32'd10;       // 10
        alu_control = 4'b0011;   // SLL

        #10;

        if (result === 32'hffffe800) begin
            $display("PASS: SLL test passed.");
        end else begin
            $display("FAIL: SLL test failed. Expected: %h, Got: %h", 32'hffffe800, result);
        end

        $finish;
    end

endmodule
