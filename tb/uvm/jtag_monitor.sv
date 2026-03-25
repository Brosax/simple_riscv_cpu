// ============================================================================
// JTAG Monitor (uvm_monitor)
// 被动观察总线信号，重建 transaction 并广播到 analysis port
// ============================================================================
`ifndef JTAG_MONITOR_SV
`define JTAG_MONITOR_SV

class jtag_monitor extends uvm_monitor;

    `uvm_component_utils(jtag_monitor)

    virtual jtag_if.monitor_mp vif;

    // analysis port：连接到 scoreboard
    uvm_analysis_port #(jtag_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual jtag_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "jtag_monitor: 无法获取虚接口 vif")
    endfunction

    task run_phase(uvm_phase phase);
        jtag_transaction tr;
        forever begin
            tr = jtag_transaction::type_id::create("mon_tr");
            collect_transaction(tr);
            `uvm_info("MON", $sformatf("采样: %s", tr.convert2string()), UVM_HIGH)
            ap.write(tr);
        end
    endtask

    // ------------------------------------------------------------------
    // 等待一次完整的 IR+DR 扫描序列并重建 transaction
    // 检测进入 SHIFT_IR 状态的方式：TMS 序列 1-1-0-0
    // ------------------------------------------------------------------
    task collect_transaction(jtag_transaction tr);
        logic [4:0]  ir_bits;
        logic [47:0] dr_bits;
        int          bit_cnt;

        ir_bits = '0;
        dr_bits = '0;
        bit_cnt = 0;

        // ----- 等待并采样 SHIFT_IR -----
        wait_for_shift_ir();
        // 收集 5 位 IR（在 SHIFT_IR 状态，TMS=0 时继续移位）
        bit_cnt = 0;
        while (1) begin
            @(vif.monitor_cb);
            ir_bits[bit_cnt] = vif.monitor_cb.tdi;
            bit_cnt++;
            if (vif.monitor_cb.tms == 1'b1) break; // EXIT1_IR
            if (bit_cnt >= 5) break;
        end
        tr.ir = jtag_transaction::jtag_ir_e'(ir_bits);

        // ----- 等待并采样 SHIFT_DR -----
        wait_for_shift_dr();
        bit_cnt = 0;
        while (bit_cnt < 48) begin
            @(vif.monitor_cb);
            dr_bits[bit_cnt] = vif.monitor_cb.tdi;
            tr.dr_out[bit_cnt] = vif.monitor_cb.tdo;
            bit_cnt++;
            if (vif.monitor_cb.tms == 1'b1) break; // EXIT1_DR
        end
        tr.dr_in = dr_bits;
    endtask

    // 等待进入 SHIFT_IR：检测 TMS 序列 1(SEL_DR)->1(SEL_IR)->0(CAP_IR)->0(SHIFT_IR)
    task wait_for_shift_ir();
        @(vif.monitor_cb iff (vif.monitor_cb.tms === 1'b1));  // SEL_DR
        @(vif.monitor_cb iff (vif.monitor_cb.tms === 1'b1));  // SEL_IR
        @(vif.monitor_cb iff (vif.monitor_cb.tms === 1'b0));  // CAP_IR
        @(vif.monitor_cb iff (vif.monitor_cb.tms === 1'b0));  // SHIFT_IR
    endtask

    // 等待进入 SHIFT_DR：检测 TMS 序列 1(SEL_DR)->0(CAP_DR)->0(SHIFT_DR)
    task wait_for_shift_dr();
        @(vif.monitor_cb iff (vif.monitor_cb.tms === 1'b1));  // SEL_DR
        @(vif.monitor_cb iff (vif.monitor_cb.tms === 1'b0));  // CAP_DR
        @(vif.monitor_cb iff (vif.monitor_cb.tms === 1'b0));  // SHIFT_DR
    endtask

endclass : jtag_monitor

`endif // JTAG_MONITOR_SV
