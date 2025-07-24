`timescale 1ns / 1ps

module tb_riscv_core;

    // --- Entradas del Core ---
    reg clk;
    reg rst;

    // --- Salidas/Entradas del Core para Periféricos ---
    wire timer_interrupt;
    wire [7:0] gpio_pins_tb; // CAMBIO: Vuelve a ser wire

    // --- Instanciación del Core ---
    riscv_core uut (
        .clk(clk),
        .rst(rst),
        .timer_interrupt(timer_interrupt),
        .gpio_pins(gpio_pins_tb)
    );

    // --- Generador de Reloj ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Reloj de 100MHz (periodo de 10ns)
    end

    // --- Secuencia de Test ---
    initial begin
        // 1. Aplicar pulso de Reset
        rst = 1;
        #20;
        rst = 0;

        // 2. Test del Temporizador
        // Escribir en mtimecmp (low 32 bits)
        #10; // Esperar un ciclo de reloj
        force uut.alu_result = 32'hFFFF0008; // Dirección de mtimecmp (low)
        force uut.reg_read_data2 = 32'd100; // Valor a comparar
        force uut.mem_write = 1'b1;
        #10;
        release uut.alu_result;
        release uut.reg_read_data2;
        release uut.mem_write;

        // Escribir en mtimecmp (high 32 bits)
        #10;
        force uut.alu_result = 32'hFFFF000C; // Dirección de mtimecmp (high)
        force uut.reg_read_data2 = 32'd0; // Valor a comparar (parte alta)
        force uut.mem_write = 1'b1;
        #10;
        release uut.alu_result;
        release uut.reg_read_data2;
        release uut.mem_write;

        // Leer mtime (low 32 bits)
        #10;
        force uut.alu_result = 32'hFFFF0000; // Dirección de mtime (low)
        force uut.mem_read = 1'b1;
        #10;
        release uut.alu_result;
        release uut.mem_read;

        // Leer mtime (high 32 bits)
        #10;
        force uut.alu_result = 32'hFFFF0004; // Dirección de mtime (high)
        force uut.mem_read = 1'b1;
        #10;
        release uut.alu_result;
        release uut.mem_read;

        // 3. Test del GPIO
        // Configurar pines 0 y 1 como salida (GPIO_DIR = 0x03)
        #10;
        force uut.alu_result = 32'hFFFF0014; // Dirección de GPIO_DIR
        force uut.reg_read_data2 = 32'h00000003; // Pines 0 y 1 como salida
        force uut.mem_write = 1'b1;
        #10;
        release uut.alu_result;
        release uut.reg_read_data2;
        release uut.mem_write;

        // Escribir en GPIO_DATA (pin 0 = 1, pin 1 = 0)
        #10;
        force uut.alu_result = 32'hFFFF0010; // Dirección de GPIO_DATA
        force uut.reg_read_data2 = 32'h00000001; // Pin 0 a 1, Pin 1 a 0
        force uut.mem_write = 1'b1;
        #10;
        release uut.alu_result;
        release uut.reg_read_data2;
        release uut.mem_write;

        // Simular entrada en pin 2 (configurado como entrada por defecto)
        force gpio_pins_tb[2] = 1'b1; // CAMBIO: Usar force
        #10;

        // Leer GPIO_DATA
        #10;
        force uut.alu_result = 32'hFFFF0010; // Dirección de GPIO_DATA
        force uut.mem_read = 1'b1;
        #10;
        release uut.alu_result;
        release uut.mem_read;
        release gpio_pins_tb[2]; // CAMBIO: Usar release
        
        // 4. Dejar correr la simulación y finalizar
        #200;
        $finish;
    end

    // --- Monitorización con $strobe ---
    always @(posedge clk) begin
        if (!rst) begin
            $strobe("Time=%0t PC=%h, Instruction=%h, Reg_x1=%h, Timer_Int=%b, GPIO_Pins=%h, Mem_Read_Data=%h",
                    $time, uut.pc_current, uut.instruction, uut.reg_file.registers[1],
                    timer_interrupt, gpio_pins_tb, uut.mem_read_data);
        end
    end

endmodule
