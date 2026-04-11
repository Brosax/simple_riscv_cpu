`timescale 1ns / 1ps
`define MAX_CYCLES 100000

module tb_isa_test;

    reg clk;
    reg rst;
    wire timer_interrupt;
    wire [7:0] gpio_pins;
    wire host_write_enable;
    wire [31:0] host_data_out;

    riscv_core uut (
        .clk(clk),
        .rst(rst),
        .timer_interrupt(timer_interrupt),
        .gpio_pins(gpio_pins),
        .host_write_enable(host_write_enable),
        .host_data_out(host_data_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    reg [4095:0] testfile;
    integer i;

    initial begin
        // Clear instruction memory (NOP) and data memory (zero)
        for (i = 0; i < 8192; i = i + 1) begin
            uut.instr_mem.mem[i] = 32'h00000013;
            uut.data_mem.mem[i]  = 8'h00;
        end

        // Load test program via +TESTFILE=<path> plusarg
        if (!$value$plusargs("TESTFILE=%s", testfile)) begin
            $display("FAIL: No +TESTFILE=<path> specified");
            $finish;
        end
        $readmemh(testfile, uut.instr_mem.mem);

        // Copy .data section into data_memory.
        // Pre-compiled test binaries (linked at 0x00000000, .data ALIGN(0x1000))
        // pack the .data section starting at binary offset 0x1000 = instr_mem word 0x400.
        // At runtime the CPU computes data addresses as 0x80001000 (PC-relative),
        // which maps to data_mem bytes [0x1000..0x1FFF].
        begin : copy_data_section
            integer di;
            for (di = 0; di < 1024; di = di + 1) begin
                uut.data_mem.mem[13'h1000 + di*4]   = uut.instr_mem.mem[13'h400 + di][7:0];
                uut.data_mem.mem[13'h1000 + di*4+1] = uut.instr_mem.mem[13'h400 + di][15:8];
                uut.data_mem.mem[13'h1000 + di*4+2] = uut.instr_mem.mem[13'h400 + di][23:16];
                uut.data_mem.mem[13'h1000 + di*4+3] = uut.instr_mem.mem[13'h400 + di][31:24];
            end
        end

        // Optional waveform dump via +WAVES plusarg
        if ($test$plusargs("WAVES")) begin
            $dumpfile("waves.vcd");
            $dumpvars(0, tb_isa_test);
        end

        rst = 1; #20; rst = 0;

        // Timeout
        #(`MAX_CYCLES * 10);
        $display("FAIL: Timeout after %0d cycles", `MAX_CYCLES);
        $finish;
    end

    // --- Primary detection: tohost write at 0x80001000 ---
    always @(posedge clk) begin
        if (!rst && host_write_enable) begin
            if (host_data_out[0] == 1'b1)
                $display("PASS");
            else
                $display("FAIL: tohost=0x%08h (test case %0d)", host_data_out, host_data_out >> 1);
            $finish;
        end
    end

    // --- Fallback detection: PC stall + register check (x26=1, x27=1/0) ---
    // Detects the infinite loop at the end of tests that use register-based pass/fail
    reg [31:0] prev_pc;
    integer stall_count;

    always @(posedge clk) begin
        if (rst) begin
            prev_pc    <= 32'h80000000;
            stall_count <= 0;
        end else begin
            if (uut.pc_reg.pc_out == prev_pc) begin
                stall_count <= stall_count + 1;
                if (stall_count >= 4) begin
                    if (uut.reg_file.registers[26] == 32'd1 &&
                        uut.reg_file.registers[27] == 32'd1)
                        $display("PASS");
                    else
                        $display("FAIL: PC stalled at 0x%08h, x26=%0d, x27=%0d",
                            uut.pc_reg.pc_out,
                            uut.reg_file.registers[26],
                            uut.reg_file.registers[27]);
                    $finish;
                end
            end else begin
                stall_count <= 0;
                prev_pc    <= uut.pc_reg.pc_out;
            end
        end
    end

endmodule
