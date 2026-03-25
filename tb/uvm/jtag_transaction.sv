// ============================================================================
// JTAG Transaction (uvm_sequence_item)
// 表示一次完整的 JTAG 操作：写 IR + 移位 DR
// ============================================================================
`ifndef JTAG_TRANSACTION_SV
`define JTAG_TRANSACTION_SV

class jtag_transaction extends uvm_sequence_item;

    `uvm_object_utils(jtag_transaction)

    // ------------------------------------------------------------------
    // 指令寄存器（5 位）
    // ------------------------------------------------------------------
    typedef enum logic [4:0] {
        IR_IDCODE = 5'b00001,
        IR_BYPASS = 5'b11111,
        IR_DBGACC = 5'b10110,
        IR_DBGRST = 5'b11010
    } jtag_ir_e;

    rand jtag_ir_e ir;          // 要写入的 IR 指令

    // ------------------------------------------------------------------
    // 数据寄存器（48 位，DBGACC 格式）
    //   dr[47]    = op    (1=写, 0=读)
    //   dr[46]    = type  (1=内存, 0=寄存器)
    //   dr[44:32] = addr
    //   dr[31:0]  = wdata
    // ------------------------------------------------------------------
    rand logic [47:0] dr_in;    // 移入 DR 的数据（LSB first）
    logic     [47:0] dr_out;   // 从 DR 移出的数据（采样结果）

    // ------------------------------------------------------------------
    // 约束：IDCODE/BYPASS 测试时 DR 为 0
    // ------------------------------------------------------------------
    constraint c_bypass_dr { if (ir == IR_BYPASS) dr_in == 48'b0; }

    function new(string name = "jtag_transaction");
        super.new(name);
    endfunction

    // 打印辅助
    function string convert2string();
        return $sformatf("IR=%0s dr_in=0x%012h dr_out=0x%012h",
                         ir.name(), dr_in, dr_out);
    endfunction

endclass : jtag_transaction

`endif // JTAG_TRANSACTION_SV
