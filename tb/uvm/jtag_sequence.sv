// ============================================================================
// JTAG Sequences
// 包含两条基本序列：IDCODE 读取 和 BYPASS 测试
// ============================================================================
`ifndef JTAG_SEQUENCE_SV
`define JTAG_SEQUENCE_SV

// ----------------------------------------------------------------------------
// 基类：所有 JTAG sequence 的父类
// ----------------------------------------------------------------------------
class jtag_base_seq extends uvm_sequence #(jtag_transaction);
    `uvm_object_utils(jtag_base_seq)
    function new(string name = "jtag_base_seq");
        super.new(name);
    endfunction
endclass

// ----------------------------------------------------------------------------
// IDCODE 读取序列
// 写入 IR=IDCODE（5'b00001），然后移出 48 位 DR，
// 期望低 32 位等于 IDCODE_VAL=0x00000001
// ----------------------------------------------------------------------------
class jtag_idcode_seq extends jtag_base_seq;

    `uvm_object_utils(jtag_idcode_seq)

    int repeat_cnt;  // 重复次数，默认 3 次

    function new(string name = "jtag_idcode_seq");
        super.new(name);
        repeat_cnt = 3;
    endfunction

    task body();
        jtag_transaction tr;
        repeat (repeat_cnt) begin
            tr = jtag_transaction::type_id::create("tr");
            start_item(tr);
            if (!tr.randomize() with { ir == jtag_transaction::IR_IDCODE; dr_in == 48'b0; })
                `uvm_fatal("SEQ", "IDCODE transaction 随机化失败")
            finish_item(tr);
            `uvm_info("SEQ_IDCODE", $sformatf("发送 IDCODE 请求: %s", tr.convert2string()), UVM_MEDIUM)
        end
    endtask

endclass : jtag_idcode_seq

// ----------------------------------------------------------------------------
// BYPASS 测试序列
// 写入 IR=BYPASS（5'b11111），验证 TDO 延迟一拍透传 TDI
// ----------------------------------------------------------------------------
class jtag_bypass_seq extends jtag_base_seq;

    `uvm_object_utils(jtag_bypass_seq)

    function new(string name = "jtag_bypass_seq");
        super.new(name);
    endfunction

    task body();
        jtag_transaction tr;

        // 测试 1：全零数据
        tr = jtag_transaction::type_id::create("tr_zero");
        start_item(tr);
        if (!tr.randomize() with { ir == jtag_transaction::IR_BYPASS; dr_in == 48'b0; })
            `uvm_fatal("SEQ", "BYPASS 全零 transaction 随机化失败")
        finish_item(tr);
        `uvm_info("SEQ_BYPASS", "BYPASS 全零测试已发送", UVM_MEDIUM)

        // 测试 2：随机数据
        tr = jtag_transaction::type_id::create("tr_rand");
        start_item(tr);
        if (!tr.randomize() with { ir == jtag_transaction::IR_BYPASS; })
            `uvm_fatal("SEQ", "BYPASS 随机 transaction 随机化失败")
        finish_item(tr);
        `uvm_info("SEQ_BYPASS", $sformatf("BYPASS 随机测试已发送: %s", tr.convert2string()), UVM_MEDIUM)
    endtask

endclass : jtag_bypass_seq

// ----------------------------------------------------------------------------
// 综合序列：先跑 IDCODE，再跑 BYPASS
// ----------------------------------------------------------------------------
class jtag_full_seq extends jtag_base_seq;

    `uvm_object_utils(jtag_full_seq)

    jtag_idcode_seq idcode_seq;
    jtag_bypass_seq bypass_seq;

    function new(string name = "jtag_full_seq");
        super.new(name);
    endfunction

    task body();
        idcode_seq = jtag_idcode_seq::type_id::create("idcode_seq");
        bypass_seq = jtag_bypass_seq::type_id::create("bypass_seq");

        `uvm_info("SEQ_FULL", "=== 开始 IDCODE 序列 ===", UVM_LOW)
        idcode_seq.start(m_sequencer);

        `uvm_info("SEQ_FULL", "=== 开始 BYPASS 序列 ===", UVM_LOW)
        bypass_seq.start(m_sequencer);
    endtask

endclass : jtag_full_seq

`endif // JTAG_SEQUENCE_SV
