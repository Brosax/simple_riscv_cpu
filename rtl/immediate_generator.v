module immediate_generator(
    input wire [31:0] instruction,
    output reg [31:0] imm_extended
);

    // El opcode determina el formato del inmediato
    wire [6:0] opcode = instruction[6:0];

    // Opcodes para los diferentes tipos de instrucción
    localparam OPCODE_I_TYPE_ARITH   = 7'b0010011;
    localparam OPCODE_I_TYPE_LOAD    = 7'b0000011;
    localparam OPCODE_JALR           = 7'b1100111;
    localparam OPCODE_S_TYPE         = 7'b0100011;
    localparam OPCODE_B_TYPE         = 7'b1100011;
    localparam OPCODE_LUI            = 7'b0110111;
    localparam OPCODE_AUIPC          = 7'b0010111;
    localparam OPCODE_JAL            = 7'b1101111;

    always @(*) begin
        case (opcode)
            // I-Type
            OPCODE_I_TYPE_ARITH, OPCODE_I_TYPE_LOAD, OPCODE_JALR:
                imm_extended = {{20{instruction[31]}}, instruction[31:20]};
            // S-Type
            OPCODE_S_TYPE:
                imm_extended = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            // B-Type
            OPCODE_B_TYPE:
                // imm[12:1] = {inst[31], inst[7], inst[30:25], inst[11:8]}
                imm_extended = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            // U-Type
            OPCODE_LUI, OPCODE_AUIPC:
                imm_extended = {instruction[31:12], 12'b0};
            // J-Type
            OPCODE_JAL:
                // imm[20:1] = {inst[31], inst[19:12], inst[20], inst[30:21]}
                imm_extended = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
                //imm_extended = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            default:
                imm_extended = 32'hxxxxxxxx;
        endcase
    end

endmodule
