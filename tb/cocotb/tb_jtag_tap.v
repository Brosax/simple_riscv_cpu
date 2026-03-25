`timescale 1ns/1ps

// Testbench wrapper for jtag_tap.v (JTAG TAP standalone test)
module tb_jtag_tap;

    reg        jtag_tck;
    reg        jtag_tms;
    reg        jtag_tdi;
    wire       jtag_tdo;
    reg        jtag_trst_n;

    wire        debug_req;
    wire        debug_write;
    wire        debug_type;
    wire [12:0] debug_addr;
    wire [31:0] debug_wdata;
    wire [31:0] debug_rdata;

    // Tie debug_rdata to a known value for IDCODE test
    assign debug_rdata = 32'h12345678;

    // Drive TRST_N high to enable TAP (active-low reset)
    initial jtag_trst_n = 1;

    jtag_tap u_dut (
        .tck           (jtag_tck),
        .tms           (jtag_tms),
        .tdi           (jtag_tdi),
        .tdo           (jtag_tdo),
        .trst_n        (jtag_trst_n),
        .debug_req     (debug_req),
        .debug_write   (debug_write),
        .debug_type    (debug_type),
        .debug_addr    (debug_addr),
        .debug_wdata   (debug_wdata),
        .debug_rdata   (debug_rdata),
        .debug_update  ()
    );

    // Clock for any registered logic
    reg clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_jtag_tap.vcd");
        $dumpvars(0, tb_jtag_tap);
        #10000;
        $display("JTAG TAP TB timed out");
        $finish;
    end

endmodule
