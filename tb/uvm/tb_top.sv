// ============================================================================
// UVM Testbench 顶层
// 实例化 DUT（jtag_tap）和 interface，启动 UVM 测试
// ============================================================================
`timescale 1ns/1ps

// 引入所有 UVM 组件
`include "uvm_macros.svh"
import uvm_pkg::*;

`include "jtag_interface.sv"
`include "jtag_transaction.sv"
`include "jtag_driver.sv"
`include "jtag_monitor.sv"
`include "jtag_scoreboard.sv"
`include "jtag_agent.sv"
`include "jtag_env.sv"
`include "jtag_sequence.sv"
`include "jtag_test.sv"

module tb_top;

    // ------------------------------------------------------------------
    // 时钟生成：TCK 周期 = 20ns（50 MHz）
    // ------------------------------------------------------------------
    logic tck;
    initial tck = 1'b0;
    always #10 tck = ~tck;

    // ------------------------------------------------------------------
    // 实例化 SystemVerilog interface
    // ------------------------------------------------------------------
    jtag_if dut_if (.tck(tck));

    // ------------------------------------------------------------------
    // 实例化 DUT：jtag_tap.v
    // ------------------------------------------------------------------
    jtag_tap dut (
        .tck          (tck),
        .tms          (dut_if.tms),
        .tdi          (dut_if.tdi),
        .tdo          (dut_if.tdo),
        .trst_n       (dut_if.trst_n),
        .debug_req    (dut_if.debug_req),
        .debug_write  (dut_if.debug_write),
        .debug_type   (dut_if.debug_type),
        .debug_addr   (dut_if.debug_addr),
        .debug_wdata  (dut_if.debug_wdata),
        .debug_rdata  (dut_if.debug_rdata),
        .debug_update (dut_if.debug_update)
    );

    // debug_rdata 在此 testbench 中固定为 0（只测 IDCODE/BYPASS）
    assign dut_if.debug_rdata = 32'h0;

    // ------------------------------------------------------------------
    // 将 interface 注册到 UVM config db，供 driver/monitor 使用
    // ------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual jtag_if)::set(null, "uvm_test_top.*", "vif", dut_if);
    end

    // ------------------------------------------------------------------
    // 波形转储（可选，用于 GTKWave 查看）
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("tb_jtag_uvm.vcd");
        $dumpvars(0, tb_top);
    end

    // ------------------------------------------------------------------
    // 启动 UVM 测试
    // ------------------------------------------------------------------
    initial begin
        run_test("jtag_test");
    end

    // 超时保护：10000 个时钟周期后强制结束
    initial begin
        #200000;
        `uvm_fatal("TIMEOUT", "仿真超时，强制结束")
    end

endmodule : tb_top
