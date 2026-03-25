// ============================================================================
// JTAG Driver (uvm_driver)
// 将 jtag_transaction 转换为 TCK/TMS/TDI 信号序列
// ============================================================================
`ifndef JTAG_DRIVER_SV
`define JTAG_DRIVER_SV

class jtag_driver extends uvm_driver #(jtag_transaction);

    `uvm_component_utils(jtag_driver)

    virtual jtag_if.driver_mp vif;  // 虚接口

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual jtag_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "jtag_driver: 无法获取虚接口 vif")
    endfunction

    task run_phase(uvm_phase phase);
        jtag_transaction tr;
        // 初始化信号，发出复位
        do_reset();
        forever begin
            seq_item_port.get_next_item(tr);
            drive_transaction(tr);
            seq_item_port.item_done();
        end
    endtask

    // ------------------------------------------------------------------
    // 复位：拉低 TRST_N 若干周期后释放
    // ------------------------------------------------------------------
    task do_reset();
        vif.driver_cb.trst_n <= 1'b0;
        vif.driver_cb.tms    <= 1'b1;
        vif.driver_cb.tdi    <= 1'b0;
        repeat(4) @(vif.driver_cb);
        vif.driver_cb.trst_n <= 1'b1;
        @(vif.driver_cb);
    endtask

    // ------------------------------------------------------------------
    // 驱动一笔 transaction：先扫描 IR，再扫描 DR
    // ------------------------------------------------------------------
    task drive_transaction(jtag_transaction tr);
        `uvm_info("DRV", $sformatf("驱动: %s", tr.convert2string()), UVM_MEDIUM)
        scan_ir(tr.ir);
        scan_dr(tr.dr_in, tr.dr_out, 48);
    endtask

    // ------------------------------------------------------------------
    // 扫描 IR（5 位，LSB first）
    //   路径：RTI -> SEL_DR -> SEL_IR -> CAP_IR -> SHIFT_IR(x5) -> EXIT1_IR -> UPD_IR -> RTI
    // ------------------------------------------------------------------
    task scan_ir(input logic [4:0] ir_val);
        // RTI -> SEL_DR
        tck_cycle(1'b1);
        // SEL_DR -> SEL_IR
        tck_cycle(1'b1);
        // SEL_IR -> CAP_IR
        tck_cycle(1'b0);
        // CAP_IR -> SHIFT_IR
        tck_cycle(1'b0);
        // SHIFT_IR：移入 5 位（最后一位时 TMS=1 跳到 EXIT1_IR）
        for (int i = 0; i < 5; i++) begin
            vif.driver_cb.tdi <= ir_val[i];
            tck_cycle((i == 4) ? 1'b1 : 1'b0);
        end
        // EXIT1_IR -> UPD_IR
        tck_cycle(1'b1);
        // UPD_IR -> RTI
        tck_cycle(1'b0);
    endtask

    // ------------------------------------------------------------------
    // 扫描 DR（len 位，LSB first），同时采样 TDO 存入 dr_out
    //   路径：RTI -> SEL_DR -> CAP_DR -> SHIFT_DR(xN) -> EXIT1_DR -> UPD_DR -> RTI
    // ------------------------------------------------------------------
    task scan_dr(input  logic [47:0] dr_in,
                 output logic [47:0] dr_out,
                 input  int          len);
        logic [47:0] captured;
        captured = '0;

        // RTI -> SEL_DR
        tck_cycle(1'b1);
        // SEL_DR -> CAP_DR
        tck_cycle(1'b0);
        // CAP_DR -> SHIFT_DR
        tck_cycle(1'b0);
        // SHIFT_DR：移入/移出 len 位
        for (int i = 0; i < len; i++) begin
            vif.driver_cb.tdi <= dr_in[i];
            @(vif.driver_cb);
            captured[i] = vif.driver_cb.tdo;
            vif.driver_cb.tms <= (i == len-1) ? 1'b1 : 1'b0;
        end
        dr_out = captured;
        // EXIT1_DR -> UPD_DR
        tck_cycle(1'b1);
        // UPD_DR -> RTI
        tck_cycle(1'b0);
    endtask

    // ------------------------------------------------------------------
    // 发出一个 TCK 周期（在下降沿设置 TMS）
    // ------------------------------------------------------------------
    task tck_cycle(input logic tms_val);
        vif.driver_cb.tms <= tms_val;
        @(vif.driver_cb);
    endtask

endclass : jtag_driver

`endif // JTAG_DRIVER_SV
