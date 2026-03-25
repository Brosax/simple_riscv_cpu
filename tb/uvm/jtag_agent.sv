// ============================================================================
// JTAG Agent (uvm_agent)
// 包含 driver + monitor，可配置为 ACTIVE（驱动）或 PASSIVE（只监听）
// ============================================================================
`ifndef JTAG_AGENT_SV
`define JTAG_AGENT_SV

class jtag_agent extends uvm_agent;

    `uvm_component_utils(jtag_agent)

    jtag_driver  driver;
    jtag_monitor monitor;

    // sequencer 负责将 sequence 产生的 item 传给 driver
    uvm_sequencer #(jtag_transaction) sequencer;

    // analysis port 透传 monitor 的输出
    uvm_analysis_port #(jtag_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap      = new("ap", this);
        monitor = jtag_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            // 主动模式：同时创建 driver 和 sequencer
            driver    = jtag_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer #(jtag_transaction)::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        // Monitor 的 analysis port 连到 agent 的 ap（再由 env 接到 scoreboard）
        monitor.ap.connect(ap);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass : jtag_agent

`endif // JTAG_AGENT_SV
