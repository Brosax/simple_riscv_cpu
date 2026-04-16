module tb_imm;
    reg [31:0] instruction;
    reg [31:0] imm_extended;
    
    always @(*) begin
        if (instruction[6:0] == 7'b1100011) // B-Type
            imm_extended = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        else if (instruction[6:0] == 7'b1101111) // J-Type
            imm_extended = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
    end
    
    initial begin
        instruction = 32'hF20004E3; // BEQ x0, x0, -216
        #1;
        $display("BEQ instruction: %h", instruction);
        $display("imm_extended: %h", imm_extended);
        $display("pc_current + imm_extended: %h", 32'h800000DC + imm_extended);
    end
endmodule
