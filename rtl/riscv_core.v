module riscv_core(
    input wire clk,
    input wire rst,
    output wire timer_interrupt, // Nueva salida para la interrupción del temporizador
    inout wire [7:0] gpio_pins,   // Nueva entrada/salida para los pines GPIO
    // --- Puertos para `tohost` ---
    output wire host_write_enable,
    output wire [31:0] host_data_out
);

    // --- Señales del Datapath ---
    wire [31:0] pc_current, pc_next, pc_plus_4, pc_branch;
    wire [31:0] instruction;
    wire [31:0] imm_extended;
    wire [31:0] alu_result, alu_operand2;
    wire [31:0] reg_read_data1, reg_read_data2;
    wire [31:0] mem_read_data; // Esta señal ahora será la salida del multiplexor de datos de lectura
    wire [31:0] write_back_data;

    // --- Señales de Control ---
    wire alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump;
    wire [1:0] alu_op;
    wire [3:0] alu_control_signal;
    wire alu_zero_flag;

    // --- Decodificación de la Instrucción ---
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    wire [4:0] rd = instruction[11:7];
    wire [2:0] funct3 = instruction[14:12];
    wire funct7_bit5 = instruction[30];

    // --- Nuevas Señales para Periféricos ---
    wire [31:0] timer_read_data;
    wire [31:0] gpio_read_data;
    wire [31:0] mem_read_data_from_data_mem; // Salida de datos de la memoria de datos

    // --- Lógica de Decodificación de Direcciones (Memory-Mapped I/O) ---
    // Rangos de direcciones:
    // Data Memory: [0x00000000 - 0xFFFEFFFF]
    // Timer:       [0xFFFF0000 - 0xFFFF000F]
    // GPIO:        [0xFFFF0010 - 0xFFFF001F]
    wire is_timer_access = (alu_result >= 32'hFFFF0000) && (alu_result <= 32'hFFFF000F);
    wire is_gpio_access = (alu_result >= 32'hFFFF0010) && (alu_result <= 32'hFFFF001F);
    wire is_tohost_access = (alu_result == TOHOST_ADDR); // Detect access to tohost
    wire is_data_mem_access = !(is_timer_access || is_gpio_access || is_tohost_access); // Exclude tohost from data memory

    // Señales de habilitación de lectura/escritura para cada componente
    wire data_mem_read_enable = mem_read && is_data_mem_access;
    wire data_mem_write_enable = mem_write && is_data_mem_access;

    wire timer_read_enable = mem_read && is_timer_access;
    wire timer_write_enable = mem_write && is_timer_access;

    wire gpio_read_enable = mem_read && is_gpio_access;
    wire gpio_write_enable = mem_write && is_gpio_access;


    // --- Instanciación de Módulos ---

    // 1. PC Register
    pc_register pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_next),
        .pc_out(pc_current)
    );

    // 2. Instruction Memory
    instruction_memory instr_mem(
        .address(pc_current),
        .instruction(instruction)
    );

    // 3. Control Unit
    control_unit ctrl_unit(
        .opcode(opcode),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_to_reg(mem_to_reg),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jump(jump)
    );

    // 4. Register File
    register_file reg_file(
        .clk(clk),
        .rst(rst),
        .read_reg1(rs1),
        .read_reg2(rs2),
        .write_reg(rd),
        .write_data(write_back_data),
        .write_enable(reg_write),
        .read_data1(reg_read_data1),
        .read_data2(reg_read_data2)
    );

    // 5. Immediate Generator
    immediate_generator imm_gen(
        .instruction(instruction),
        .imm_extended(imm_extended)
    );

    // 6. ALU Control Unit
    alu_control_unit alu_ctrl(
        .alu_op(alu_op),
        .funct3(funct3),
        .funct7_bit5(funct7_bit5),
        .alu_control(alu_control_signal)
    );

    // 7. ALU
    wire [31:0] alu_operand1;
    assign alu_operand1 = (opcode == 7'b0010111) ? pc_current : // AUIPC
                          (opcode == 7'b0110111) ? 32'b0 :      // LUI
                          reg_read_data1;

    assign alu_operand2 = alu_src ? imm_extended : reg_read_data2;
    alu alu_inst(
        .operand1(alu_operand1),
        .operand2(alu_operand2),
        .alu_control(alu_control_signal),
        .result(alu_result),
        .zero(alu_zero_flag)
    );

    // 8. Data Memory
    data_memory data_mem(
        .clk(clk),
        .address(alu_result),
        .write_data(reg_read_data2),
        .write_enable(data_mem_write_enable), // Habilitación controlada por el decodificador
        .read_data(mem_read_data_from_data_mem),
        .funct3(funct3)
    );

    // 9. Timer
    timer timer_inst(
        .clk(clk),
        .rst(rst),
        .address(alu_result),
        .write_data(reg_read_data2),
        .write_enable(timer_write_enable), // Habilitación controlada por el decodificador
        .read_data(timer_read_data),
        .interrupt(timer_interrupt)
    );

    // 10. GPIO
    gpio gpio_inst(
        .clk(clk),
        .rst(rst),
        .address(alu_result),
        .write_data(reg_read_data2),
        .write_enable(gpio_write_enable), // Habilitación controlada por el decodificador
        .read_data(gpio_read_data),
        .gpio_pins(gpio_pins)
    );

    // --- Lógica de `tohost` para riscv-tests ---
    localparam TOHOST_ADDR = 32'h80001000;
    assign host_write_enable = mem_write && (alu_result == TOHOST_ADDR);
    assign host_data_out = reg_read_data2;

    // --- Multiplexación de Datos de Lectura para mem_read_data ---
    // Selecciona los datos de lectura de la memoria de datos o del periférico correspondiente
    assign mem_read_data = is_timer_access ? timer_read_data :
                           is_gpio_access ? gpio_read_data :
                           mem_read_data_from_data_mem; // Por defecto, de la memoria de datos

    // --- Lógica de Siguiente PC ---
    assign pc_plus_4 = pc_current + 4;
    wire [31:0] pc_target_imm = pc_current + imm_extended; // Para JAL y Branch

    // La ALU calcula reg1 + imm para JALR. El resultado debe ser alineado.
    wire [31:0] pc_target_jalr = {alu_result[31:1], 1'b0};

    wire take_branch;
    // Condición para tomar un salto condicional basado en funct3 y las banderas de la ALU
    // Para saltos, la ALU realiza una resta (para BEQ/BNE) o una comparación (para SLT/SLTU)
    // El resultado de la ALU (alu_result) o la bandera zero (alu_zero_flag) determina la decisión.
    assign take_branch = (branch & (
        (funct3 == 3'b000 & alu_zero_flag)   |      // BEQ: branch if zero
        (funct3 == 3'b001 & ~alu_zero_flag)  |      // BNE: branch if not zero
        (funct3 == 3'b100 & alu_result[0])   |      // BLT: branch if less than (result of SLT is 1)
        (funct3 == 3'b101 & ~alu_result[0])  |      // BGE: branch if greater or equal (result of SLT is 0)
        (funct3 == 3'b110 & alu_result[0])   |      // BLTU: branch if less than unsigned (result of SLTU is 1)
        (funct3 == 3'b111 & ~alu_result[0])        // BGEU: branch if greater or equal unsigned (result of SLTU is 0)
    ));

    // Multiplexor para el siguiente valor del PC.
    assign pc_next = (jump && opcode == 7'b1101111) ? pc_target_imm :      // JAL
                     (jump && opcode == 7'b1100111) ? pc_target_jalr :     // JALR
                     take_branch ? pc_target_imm :
                     pc_plus_4;

    // --- Lógica de Write Back ---
    // Para JAL/JALR, se escribe pc+4 en rd. De lo contrario, se usa el resultado de la ALU o de la Memoria.
    assign write_back_data = jump ? pc_plus_4 : (mem_to_reg ? mem_read_data : alu_result);


    // --- Debug Trace Logic ---
    always @(posedge clk)
    begin
        if(!rst)
        begin
            $display("PC: %h, INST: %h, reg_write: %b, rd: %d, wb_data: %h, alu_res: %h, op1: %h, op2: %h, alu_ctrl: %b", 
                     pc_current, instruction, reg_write, rd, write_back_data, alu_result, alu_operand1, alu_operand2, alu_control_signal);
        end
    end

endmodule
