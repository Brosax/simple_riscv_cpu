`timescale 1ns/1ps

// Testbench wrapper for riscv_core_jtag.v (full integration test)
module tb_riscv_core_jtag;

    reg         clk;
    reg         rst;

    wire         timer_interrupt;
    wire  [7:0]  gpio_pins;
    wire         host_write_enable;
    wire  [31:0] host_data_out;

    // JTAG
    reg         jtag_tck;
    reg         jtag_tms;
    reg         jtag_tdi;
    wire        jtag_tdo;
    reg         jtag_trst_n;

    // GPIO bidir drive
    assign gpio_pins = 8'h00;

    riscv_core_jtag u_dut (
        .clk               (clk),
        .rst               (rst),
        .timer_interrupt   (timer_interrupt),
        .gpio_pins         (gpio_pins),
        .host_write_enable (host_write_enable),
        .host_data_out     (host_data_out),
        .jtag_tck          (jtag_tck),
        .jtag_tms          (jtag_tms),
        .jtag_tdi          (jtag_tdi),
        .jtag_tdo          (jtag_tdo),
        .jtag_trst_n       (jtag_trst_n)
    );

    // CPU clock: 50 MHz (20 ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Reset: assert for 5 cycles, then release
    initial begin
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
    end

    initial begin
        $dumpfile("tb_riscv_core_jtag.vcd");
        $dumpvars(0, tb_riscv_core_jtag);
        #50000;
        $display("Integration TB timed out");
        $finish;
    end

endmodule
