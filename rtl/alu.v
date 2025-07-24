module alu(
    input wire [31:0] operand1,
    input wire [31:0] operand2,
    input wire [3:0] alu_control,
    output reg [31:0] result,
    output wire zero
);

    // Lógica combinacional para las operaciones de la ALU
    always @(*) begin
        case (alu_control)
            4'b0000: result = operand1 & operand2; // AND
            4'b0001: result = operand1 | operand2; // OR
            4'b0010: result = operand1 + operand2; // ADD
            4'b0011: result = operand1 << operand2[4:0]; // SLL
            4'b0100: result = operand1 >> operand2[4:0]; // SRL
            4'b0101: result = $signed(operand1) >>> operand2[4:0]; // SRA
            4'b0110: result = operand1 - operand2; // SUB
            4'b0111: result = ($signed(operand1) < $signed(operand2)) ? 32'd1 : 32'd0; // SLT
            4'b1000: result = (operand1 < operand2) ? 32'd1 : 32'd0; // SLTU
            4'b1001: result = operand1 ^ operand2; // XOR
            default: result = 32'hxxxxxxxx; // Valor por defecto
        endcase
    end

    // La bandera 'zero' se activa si el resultado es 0
    assign zero = (result == 32'b0);

endmodule
