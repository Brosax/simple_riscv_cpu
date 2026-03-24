
`timescale 1ns / 1ps
`define MAX_CYCLES 500000 // Failsafe timeout for the simulation

module tb_riscv_core;

    // --- Entradas del Core ---
    reg clk;
    reg rst;

    // --- Salidas/Entradas del Core ---
    wire timer_interrupt;
    wire [7:0] gpio_pins;
    wire host_write_enable;
    wire [31:0] host_data_out;

    // --- Instanciación del Core (DUT - Design Under Test) ---
    riscv_core uut (
        .clk(clk),
        .rst(rst),
        .timer_interrupt(timer_interrupt),
        .gpio_pins(gpio_pins),
        .host_write_enable(host_write_enable),
        .host_data_out(host_data_out)
    );

    // --- Generador de Reloj ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Reloj de 100MHz (periodo de 10ns)
    end

    // --- Secuencia de Test ---
    initial begin
        reg [255*8:0] test_program_file;
        integer file;

        // 1. Leer el nombre del programa de test desde un fichero
        file = $fopen("test_program.txt", "r");
        if (file) begin
            $fscanf(file, "%s", test_program_file);
            $fclose(file);
            $display("L_INFO: Loading test program: %s", test_program_file);
        
            // 2. Cargar el programa en la memoria de instrucciones del DUT
            $readmemh(test_program_file, uut.instr_mem.mem);
        end else begin
            $display("L_ERROR: test_program.txt not found. Aborting.");
            $finish;
        end

        // 3. Aplicar pulso de Reset
        rst = 1;
        #20;
        rst = 0;

        // 4. Failsafe: terminar la simulación si dura demasiado
        #(`MAX_CYCLES * 10); // Tiempo de espera en ns
        $display("L_FAIL: Simulation timed out after %d cycles.", `MAX_CYCLES);
        $finish;
    end

    // --- Lógica de Verificación y Finalización ---
    // Monitorea la señal `tohost` para determinar el resultado del test
    always @(posedge clk) begin
        if (host_write_enable) begin
            if (host_data_out[0] == 1'b1) begin
                // Test program indicates a pass, now dump signature for verification
                dump_signature();
            end else begin
                $display("L_FAIL: Test Failed with tohost code %h", host_data_out >> 1);
            end
            $finish; // Terminar la simulación
        end
    end

    // --- Tarea para volcar la firma del banco de registros ---
    task dump_signature;
        integer file;
        integer i;
        file = $fopen("signature.log", "w");
        if (file) begin
            for (i = 0; i < 32; i = i + 1) begin
                // El formato del dump es de 8 dígitos hexadecimales por línea
                $fdisplay(file, "%08h", uut.reg_file.registers[i]);
            end
            $fclose(file);
        end else begin
            $display("L_ERROR: Could not open signature.log for writing.");
        end
    endtask

    always @(posedge clk) begin
        if (rst == 0) begin
            $display("PC: %h", uut.pc_current);
        end
    end

    
    // --- Generación de VCD para debugging ---
    initial begin
        $dumpfile("tb_riscv_core.vcd");
        $dumpvars(0, tb_riscv_core);
    end
    

endmodule
