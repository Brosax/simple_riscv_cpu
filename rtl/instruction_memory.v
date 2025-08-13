module instruction_memory(
    input wire [31:0] address,
    output wire [31:0] instruction
);

    // Memoria para almacenar las instrucciones (ej: 8192 instrucciones de 32 bits)
    reg [31:0] mem[0:8191];

    // La lectura es asíncrona.
    // Se restan 0x80000000 de la dirección para mapear el inicio del programa a la dirección 0 de la memoria.
    // Luego se divide por 4 para direccionar palabras.
    assign instruction = mem[(address - 32'h80000000) >> 2];

endmodule