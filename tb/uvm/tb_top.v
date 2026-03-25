`timescale 1ns/1ps
// ============================================================================
// pyuvm Testbench 顶层 Verilog 包装器
// 实例化 DUT（jtag_tap.v），信号由 cocotb/pyuvm 的 Python 层驱动
// ============================================================================
module tb_top;

    // JTAG 信号（cocotb 通过 DUT handle 直接操作）
    reg        jtag_tck;
    reg        jtag_tms;
    reg        jtag_tdi;
    wire       jtag_tdo;
    reg        jtag_trst_n;

    // 调试端口（此 testbench 只测 IDCODE/BYPASS，debug_rdata 固定为 0）
    wire        debug_req;
    wire        debug_write;
    wire        debug_type;
    wire [12:0] debug_addr;
    wire [31:0] debug_wdata;
    reg  [31:0] debug_rdata;
    wire        debug_update;

    // 初始化：复位有效（低电平），信号默认低
    initial begin
        jtag_tck    = 0;
        jtag_tms    = 0;
        jtag_tdi    = 0;
        jtag_trst_n = 0;
        debug_rdata = 32'h0;
    end

    // 实例化被测设计
    jtag_tap u_dut (
        .tck          (jtag_tck),
        .tms          (jtag_tms),
        .tdi          (jtag_tdi),
        .tdo          (jtag_tdo),
        .trst_n       (jtag_trst_n),
        .debug_req    (debug_req),
        .debug_write  (debug_write),
        .debug_type   (debug_type),
        .debug_addr   (debug_addr),
        .debug_wdata  (debug_wdata),
        .debug_rdata  (debug_rdata),
        .debug_update (debug_update)
    );

    // 波形转储（GTKWave 查看用）
    initial begin
        $dumpfile("tb_jtag_pyuvm.vcd");
        $dumpvars(0, tb_top);
    end

    // 超时保护：防止仿真挂起
    initial begin
        #500000;
        $display("[TIMEOUT] 仿真超时，强制结束");
        $finish;
    end

endmodule
