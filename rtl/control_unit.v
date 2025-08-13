module control_unit(
    input wire [6:0] opcode,

    // Control Signals
    output reg alu_src,
    output reg [1:0] alu_op,
    output reg mem_to_reg,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg branch,
    output reg jump
);

    // Opcodes for different instruction types
    localparam OPCODE_R_TYPE = 7'b0110011;
    localparam OPCODE_I_TYPE_ARITH = 7'b0010011;
    localparam OPCODE_I_TYPE_LOAD = 7'b0000011;
    localparam OPCODE_S_TYPE = 7'b0100011;
    localparam OPCODE_B_TYPE = 7'b1100011;
    localparam OPCODE_JAL = 7'b1101111;
    localparam OPCODE_JALR = 7'b1100111;
    localparam OPCODE_LUI = 7'b0110111;
    localparam OPCODE_AUIPC = 7'b0010111;

    always @(*) begin
        // Default values
        alu_src = 1'b0;
        alu_op = 2'b00;
        mem_to_reg = 1'b0;
        reg_write = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        branch = 1'b0;
        jump = 1'b0;

        case (opcode)
            OPCODE_R_TYPE: begin
                reg_write = 1'b1;
                alu_src = 1'b0;
                alu_op = 2'b10;
            end
            OPCODE_I_TYPE_ARITH: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = 2'b00;
            end
            OPCODE_I_TYPE_LOAD: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                mem_read = 1'b1;
                mem_to_reg = 1'b1;
                alu_op = 2'b11; // Use ALU_ADD for address calculation
            end
            OPCODE_S_TYPE: begin
                alu_src = 1'b1;
                mem_write = 1'b1;
                alu_op = 2'b11;
            end
            OPCODE_B_TYPE: begin
                branch = 1'b1;
                alu_src = 1'b0;
                alu_op = 2'b01;
            end
            OPCODE_JAL: begin
                reg_write = 1'b1;
                jump = 1'b1;
            end
            OPCODE_JALR: begin
                reg_write = 1'b1;
                jump = 1'b1;
                alu_src = 1'b1;
                alu_op = 2'b00; // Crucial fix: Set ALU op for address calculation
            end
            OPCODE_LUI: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = 2'b11; // Special case for LUI
            end
            OPCODE_AUIPC: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = 2'b11;
            end
        endcase
    end

endmodule
