// ============================================================================
// JTAG Scoreboard (uvm_scoreboard)
// 检查 IDCODE 和 BYPASS 的返回值是否正确
// ============================================================================
`ifndef JTAG_SCOREBOARD_SV
`define JTAG_SCOREBOARD_SV

class jtag_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(jtag_scoreboard)

    // 接收来自 monitor 的 transaction
    uvm_analysis_imp #(jtag_transaction, jtag_scoreboard) analysis_export;

    // 统计计数
    int pass_cnt;
    int fail_cnt;

    // DUT 定义的 IDCODE 值（见 jtag_tap.v 第 102 行）
    localparam logic [31:0] EXPECTED_IDCODE = 32'h00000001;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        pass_cnt = 0;
        fail_cnt = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
    endfunction

    // ------------------------------------------------------------------
    // 每收到一笔 transaction 就执行检查
    // ------------------------------------------------------------------
    function void write(jtag_transaction tr);
        case (tr.ir)

            jtag_transaction::IR_IDCODE: begin
                // IDCODE：DR 移出低 32 位应等于 EXPECTED_IDCODE
                logic [31:0] got_id = tr.dr_out[31:0];
                if (got_id === EXPECTED_IDCODE) begin
                    `uvm_info("SCB", $sformatf("PASS IDCODE: 0x%08h == 0x%08h",
                              got_id, EXPECTED_IDCODE), UVM_LOW)
                    pass_cnt++;
                end else begin
                    `uvm_error("SCB", $sformatf("FAIL IDCODE: 得到 0x%08h，期望 0x%08h",
                               got_id, EXPECTED_IDCODE))
                    fail_cnt++;
                end
            end

            jtag_transaction::IR_BYPASS: begin
                // BYPASS：TDO 应延迟一个时钟输出 TDI，
                // 即 dr_out 应该是 dr_in 右移一位（最高位为 0）
                // 简化检查：bypass DR 为全 0 时，dr_out 应全 0
                if (tr.dr_in == 48'b0 && tr.dr_out == 48'b0) begin
                    `uvm_info("SCB", "PASS BYPASS: dr_out 正确为全 0", UVM_LOW)
                    pass_cnt++;
                end else if (tr.dr_in != 48'b0) begin
                    // 非零数据：dr_out 应是 dr_in 右移一位
                    logic [47:0] expected = {1'b0, tr.dr_in[47:1]};
                    if (tr.dr_out === expected) begin
                        `uvm_info("SCB", "PASS BYPASS: 移位正确", UVM_LOW)
                        pass_cnt++;
                    end else begin
                        `uvm_error("SCB", $sformatf("FAIL BYPASS: 得到 0x%012h，期望 0x%012h",
                                   tr.dr_out, expected))
                        fail_cnt++;
                    end
                end
            end

            default: begin
                // 其他指令暂不检查
                `uvm_info("SCB", $sformatf("跳过检查 IR=%0s", tr.ir.name()), UVM_HIGH)
            end

        endcase
    endfunction

    // 最终报告
    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("=== Scoreboard 结果: PASS=%0d  FAIL=%0d ===",
                  pass_cnt, fail_cnt), UVM_NONE)
        if (fail_cnt > 0)
            `uvm_error("SCB", "存在失败的检查项！")
    endfunction

endclass : jtag_scoreboard

`endif // JTAG_SCOREBOARD_SV
