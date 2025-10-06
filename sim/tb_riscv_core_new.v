`timescale 1ns / 1ps
`define MAX_CYCLES 500000 // Failsafe timeout for the simulation

module tb_riscv_core_new;

    // --- Core Inputs ---
    reg clk;
    reg rst;

    // --- Core Outputs/IOs ---
    wire timer_interrupt;
    wire [7:0] gpio_pins;
    wire host_write_enable;
    wire [31:0] host_data_out;

    // --- DUT (Design Under Test) Instantiation ---
    riscv_core uut (
        .clk(clk),
        .rst(rst),
        .timer_interrupt(timer_interrupt),
        .gpio_pins(gpio_pins),
        .host_write_enable(host_write_enable),
        .host_data_out(host_data_out)
    );

    // --- Clock Generator ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock (10ns period)
    end

    // --- Test Sequence ---
    initial begin
        integer i;
        $display("L_INFO: Testbench initial block starting...");

        // 1. Initialize instruction memory to 0 (NOP)
        for (i = 0; i < 8192; i = i + 1) begin
            uut.instr_mem.mem[i] = 32'h00000000;
        end

        // 2. Load the program from a pre-processed memory file
        $display("L_INFO: Loading test program from inst.mem");
        $readmemh("inst.mem", uut.instr_mem.mem);

        // 3. Apply Reset Pulse
        rst = 1;
        #20;
        rst = 0;

        // 4. Failsafe: terminate the simulation if it runs for too long
        #(`MAX_CYCLES * 10); // Wait time in ns
        $display("L_FAIL: Simulation timed out after %d cycles.", `MAX_CYCLES);
        $finish;
    end

    // --- Verification and Termination Logic ---
    // Monitors for two types of test completion:
    // 1. A write to the `tohost` address (standard riscv-tests).
    // 2. Specific register values being set (used by other test suites).
    always @(posedge clk) begin
        integer file;
        integer i;

        // Check for `tohost` write
        if (host_write_enable) begin
            if (host_data_out[0] == 1'b1) begin
                $display("L_INFO: Test passed (via tohost), writing signature.log");
                // Inlined dump_signature logic
                file = $fopen("signature.log", "w");
                if (file) begin
                    for (i = 0; i < 32; i = i + 1) begin $fdisplay(file, "%08h", uut.reg_file.registers[i]); end
                    $fclose(file);
                end else begin $display("L_ERROR: Could not open signature.log for writing."); end
            end else begin
                $display("L_FAIL: Test Failed with tohost code %h", host_data_out >> 1);
            end
            $finish; // End simulation
        end

        // Check for register-based completion signal (x26=1 and x27=1)
        if (uut.reg_file.registers[26] == 32'd1 && uut.reg_file.registers[27] == 32'd1) begin
            $display("L_INFO: Test passed (via register check), writing signature.log");
            // Inlined dump_signature logic
            file = $fopen("signature.log", "w");
            if (file) begin
                for (i = 0; i < 32; i = i + 1) begin $fdisplay(file, "%08h", uut.reg_file.registers[i]); end
                $fclose(file);
            end else begin $display("L_ERROR: Could not open signature.log for writing."); end
            $finish; // End simulation
        end
    end

    // --- VCD Waveform Generation for debugging ---
    initial begin
        $dumpfile("tb_riscv_core_new.vcd");
        $dumpvars(0, tb_riscv_core_new);
    end

endmodule