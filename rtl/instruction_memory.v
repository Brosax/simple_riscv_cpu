module instruction_memory(
    input wire [31:0] address,
    output wire [31:0] instruction
);

    // Memoria para almacenar las instrucciones (ej: 1024 instrucciones de 32 bits)
    reg [31:0] mem[0:1023];

    // Inicialización de la memoria con un programa de test para RV32I
    initial begin
        // Test Program for RV32I
        // 1. Setup
        mem[0]  = 32'h00a00093; // 0x00: addi x1, x0, 10
        mem[1]  = 32'hfec00113; // 0x04: addi x2, x0, -20
        // 2. I-Type Arithmetic
        mem[2]  = 32'h00508193; // 0x08: addi  x3, x1, 5
        mem[3]  = 32'h00a14213; // 0x0c: slti  x4, x2, 10
        mem[4]  = 32'h00a15293; // 0x10: sltiu x5, x2, 10
        mem[5]  = 32'hf0f0c313; // 0x14: xori  x6, x1, 0xf0f
        mem[6]  = 32'hf0f0e393; // 0x18: ori   x7, x1, 0xf0f
        mem[7]  = 32'hf0f0f413; // 0x1c: andi  x8, x1, 0xf0f
        mem[8]  = 32'h00209493; // 0x20: slli  x9, x1, 2
        mem[9]  = 32'h0020d513; // 0x24: srli  x10, x1, 2
        mem[10] = 32'h40215593; // 0x28: srai  x11, x2, 2
        // 3. R-Type Arithmetic
        mem[11] = 32'h00208633; // 0x2c: add   x12, x1, x2
        mem[12] = 32'h402086b3; // 0x30: sub   x13, x1, x2
        mem[13] = 32'h00112733; // 0x34: slt   x14, x2, x1
        mem[14] = 32'h001137b3; // 0x38: sltu  x15, x2, x1
        mem[15] = 32'h0020c833; // 0x3c: xor   x16, x1, x2
        mem[16] = 32'h0020e8b3; // 0x40: or    x17, x1, x2
        mem[17] = 32'h0020f933; // 0x44: and   x18, x1, x2
        mem[18] = 32'h00a099b3; // 0x48: sll   x19, x1, x1
        mem[19] = 32'h00ada33;  // 0x4c: srl   x20, x1, x1
        mem[20] = 32'h40a15ab3; // 0x50: sra   x21, x2, x1
        // 4. Memory Store
        mem[21] = 32'hfec02023; // 0x54: sw    x12, 0(x0)
        mem[22] = 32'h00d01223; // 0x58: sh    x13, 4(x0)
        mem[23] = 32'h00100323; // 0x5c: sb    x1, 6(x0)
        // 5. Memory Load
        mem[24] = 32'h00002b03; // 0x60: lw    x22, 0(x0)
        mem[25] = 32'h00401b83; // 0x64: lh    x23, 4(x0)
        mem[26] = 32'h00405c03; // 0x68: lhu   x24, 4(x0)
        mem[27] = 32'h00600c83; // 0x6c: lb    x25, 6(x0)
        mem[28] = 32'h00604d03; // 0x70: lbu   x26, 6(x0)
        // 6. LUI/AUIPC
        mem[29] = 32'habcded37; // 0x74: lui   x27, 0xabcde
        mem[30] = 32'h00000e17; // 0x78: auipc x28, 0
        // 7. Branches
        mem[31] = 32'h00500e93; // 0x7c: addi x29, x0, 5
        mem[32] = 32'h00500f13; // 0x80: addi x30, x0, 5
        mem[33] = 32'h00fe8463; // 0x84: beq   x29, x30, 8c <beq_taken>
        mem[34] = 32'h00000013; // 0x88: nop (skipped)
        mem[35] = 32'h001e9463; // 0x8c: bne   x29, x1, 94 <bne_taken>
        mem[36] = 32'h00000013; // 0x90: nop (skipped)
        mem[37] = 32'h01d14463; // 0x94: blt   x2, x29, 9c <blt_taken>
        mem[38] = 32'h00000013; // 0x98: nop (skipped)
        mem[39] = 32'h002ed463; // 0x9c: bge   x29, x2, a4 <bge_taken>
        mem[40] = 32'h00000013; // 0xa0: nop (skipped)
        mem[41] = 32'h01de6463; // 0xa4: bltu  x29, x2, ac <bltu_taken>
        mem[42] = 32'h00000013; // 0xa8: nop (skipped)
        mem[43] = 32'h002ef463; // 0xac: bgeu  x2, x29, b4 <bgeu_taken>
        mem[44] = 32'h00000013; // 0xb0: nop (skipped)
        mem[45] = 32'h00208463; // 0xb4: beq   x1, x2, bc <not_taken>
        mem[46] = 32'h00000013; // 0xb8: nop (executed)
        // 8. Jumps
        mem[47] = 32'h00800f6f; // 0xbc: jal   x31, c4 <jal_target>
        mem[48] = 32'h00000013; // 0xc0: nop (will be returned to by jalr)
        mem[49] = 32'h06400093; // 0xc4: addi x1, x0, 100 (jal_target)
        mem[50] = 32'h000f80e7; // 0xc8: jalr  x1, x31, 0
        // 9. End
        mem[51] = 32'h00000063; // 0xcc: beq x0, x0, cc <end_loop>
    end

    // La lectura es asíncrona. La dirección se divide por 4 para direccionar palabras.
    assign instruction = mem[address[11:2]];

endmodule
