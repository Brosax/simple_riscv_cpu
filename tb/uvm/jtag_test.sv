// ============================================================================
// JTAG Test (uvm_test)
// 顶层测试类：创建环境并启动测试序列
// ============================================================================
`ifndef JTAG_TEST_SV
`define JTAG_TEST_SV

class jtag_test extends uvm_test;

    `uvm_component_utils(jtag_test)

    jtag_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = jtag_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        jtag_full_seq seq;
        phase.raise_objection(this, "启动测试");

        `uvm_info("TEST", "=== JTAG UVM Testbench 开始 ===", UVM_NONE)
        seq = jtag_full_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        `uvm_info("TEST", "=== JTAG UVM Testbench 结束 ===", UVM_NONE)

        phase.drop_objection(this, "测试完成");
    endtask

endclass : jtag_test

`endif // JTAG_TEST_SV
