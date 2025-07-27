module alu_control_unit(
    input wire [1:0] alu_op,
    input wire [2:0] funct3,
    input wire funct7_bit5, // Corresponds to bit 30 of the instruction
    output reg [3:0] alu_control
);

    // ALU Operation signals (matching alu.v)
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

    always @(*) begin
        case(alu_op)
            // I-Type
            2'b00: begin
                case(funct3)
                    3'b000: alu_control = ALU_ADD;  // ADDI
                    3'b001: alu_control = ALU_SLL;  // SLLI
                    3'b010: alu_control = ALU_SLT;  // SLTI
                    3'b011: alu_control = ALU_SLTU; // SLTIU
                    3'b100: alu_control = ALU_XOR;  // XORI
                    3'b101: alu_control = (funct7_bit5) ? ALU_SRA : ALU_SRL; // SRAI, SRLI
                    3'b110: alu_control = ALU_OR;   // ORI
                    3'b111: alu_control = ALU_AND;  // ANDI
                    default: alu_control = 4'hX;
                endcase
            end
            // R-Type
            2'b10: begin
                case (funct3)
                    3'b000: alu_control = (funct7_bit5) ? ALU_SUB : ALU_ADD; // SUB, ADD
                    3'b001: alu_control = ALU_SLL;  // SLL
                    3'b010: alu_control = ALU_SLT;  // SLT
                    3'b011: alu_control = ALU_SLTU; // SLTU
                    3'b100: alu_control = ALU_XOR;  // XOR
                    3'b101: alu_control = (funct7_bit5) ? ALU_SRA : ALU_SRL; // SRA, SRL
                    3'b110: alu_control = ALU_OR;   // OR
                    3'b111: alu_control = ALU_AND;  // AND
                    default: alu_control = 4'hX;
                endcase
            end
            // B-Type
            2'b01: begin
                case (funct3)
                    3'b000, 3'b001: alu_control = ALU_SUB;  // BEQ, BNE (比较是否相等 -> sub)
                    3'b100, 3'b101: alu_control = ALU_SLT;  // BLT, BGE (有符号比较 -> slt)
                    3'b110, 3'b111: alu_control = ALU_SLTU; // BLTU, BGEU (无符号比较 -> sltu)
                    default: alu_control = 4'hX;
                endcase
            end
            // U-Type and Load address calculation
            2'b11: begin
                alu_control = ALU_ADD;
            end

            default: begin
                alu_control = 4'hX;
            end
        endcase


        /*
        if (alu_op == 2'b00) begin // I-Type
            if (funct3 == 3'b000) alu_control = ALU_ADD;
            else if (funct3 == 3'b001) alu_control = ALU_SLL;
            else if (funct3 == 3'b010) alu_control = ALU_SLT;
            else if (funct3 == 3'b011) alu_control = ALU_SLTU;
            else if (funct3 == 3'b100) alu_control = ALU_XOR;
            else if (funct3 == 3'b101) alu_control = (funct7_bit5) ? ALU_SRA : ALU_SRL;
            else if (funct3 == 3'b110) alu_control = ALU_OR;
            else if (funct3 == 3'b111) alu_control = ALU_AND;
            else alu_control = 4'hX;
        end else if (alu_op == 2'b10) begin // R-Type
            if (funct3 == 3'b000) alu_control = (funct7_bit5) ? ALU_SUB : ALU_ADD;
            else if (funct3 == 3'b001) alu_control = ALU_SLL;
            else if (funct3 == 3'b010) alu_control = ALU_SLT;
            else if (funct3 == 3'b011) alu_control = ALU_SLTU;
            else if (funct3 == 3'b100) alu_control = ALU_XOR;
            else if (funct3 == 3'b101) alu_control = (funct7_bit5) ? ALU_SRA : ALU_SRL;
            else if (funct3 == 3'b110) alu_control = ALU_OR;
            else if (funct3 == 3'b111) alu_control = ALU_AND;
            else alu_control = 4'hX;
        end else if (alu_op == 2'b01) begin // B-Type
            if (funct3 == 3'b000) alu_control = ALU_SUB; // BEQ
            else if (funct3 == 3'b001) alu_control = ALU_SUB; // BNE
            else if (funct3 == 3'b100) alu_control = ALU_SLT; // BLT
            else if (funct3 == 3'b101) alu_control = ALU_SLT; // BGE
            else if (funct3 == 3'b110) alu_control = ALU_SLTU; // BLTU
            else if (funct3 == 3'b111) alu_control = ALU_SLTU; // BGEU
            else alu_control = 4'hX;
        end else if (alu_op == 2'b11) begin // U-Type and Load address calculation
            alu_control = ALU_ADD;
        end else begin
            alu_control = 4'hX;
        end
        */
    end

endmodule