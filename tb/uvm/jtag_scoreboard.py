"""
jtag_scoreboard.py — uvm_scoreboard
接收来自 monitor 的 JtagTransaction，验证 IDCODE 和 BYPASS 的正确性。

检查规则：
  - IDCODE：DR 移出低 32 位应等于 0x00000001（见 jtag_tap.v IDCODE_VAL）
  - BYPASS：TDO 应延迟一拍透传 TDI（dr_out == dr_in >> 1）
"""
from pyuvm import uvm_scoreboard, uvm_tlm_analysis_fifo

from jtag_transaction import JtagTransaction, IR_IDCODE, IR_BYPASS

# DUT 中定义的 IDCODE 值（jtag_tap.v）
EXPECTED_IDCODE = 0x00000001


class JtagScoreboard(uvm_scoreboard):
    """
    UVM Scoreboard：通过 uvm_tlm_analysis_fifo 接收事务并执行断言检查。
    """

    def build_phase(self):
        # analysis FIFO：接收来自 monitor 的事务（内部缓冲，异步消费）
        self.analysis_fifo   = uvm_tlm_analysis_fifo("analysis_fifo", self)
        # 对外暴露 export，供 env 的 connect_phase 连接 monitor.ap
        self.analysis_export = self.analysis_fifo.analysis_export
        # 统计计数
        self.pass_cnt = 0
        self.fail_cnt = 0

    async def run_phase(self):
        """主循环：持续从 FIFO 取事务并检查"""
        while True:
            tr = await self.analysis_fifo.get()
            self._check(tr)

    def _check(self, tr: JtagTransaction):
        """根据 IR 类型执行对应检查"""
        if tr.ir == IR_IDCODE:
            self._check_idcode(tr)
        elif tr.ir == IR_BYPASS:
            self._check_bypass(tr)
        else:
            self.logger.debug(f"跳过检查 IR=0x{tr.ir:02x}（非 IDCODE/BYPASS）")

    def _check_idcode(self, tr: JtagTransaction):
        """IDCODE 检查：低 32 位必须等于 EXPECTED_IDCODE"""
        got = tr.dr_out & 0xFFFFFFFF
        if got == EXPECTED_IDCODE:
            self.logger.info(
                f"PASS IDCODE: 得到 0x{got:08x} == 期望 0x{EXPECTED_IDCODE:08x}"
            )
            self.pass_cnt += 1
        else:
            self.logger.error(
                f"FAIL IDCODE: 得到 0x{got:08x}，期望 0x{EXPECTED_IDCODE:08x}"
            )
            self.fail_cnt += 1

    def _check_bypass(self, tr: JtagTransaction):
        """
        BYPASS 检查：TDO 比 TDI 延迟一拍，
        即 dr_out == dr_in >> 1（最高位补 0）
        """
        bits     = tr.dr_bits
        mask     = (1 << bits) - 1
        expected = (tr.dr_in >> 1) & mask
        got      = tr.dr_out & mask

        if got == expected:
            self.logger.info(
                f"PASS BYPASS: dr_out=0x{got:x} == 期望 0x{expected:x}"
            )
            self.pass_cnt += 1
        else:
            self.logger.error(
                f"FAIL BYPASS: dr_out=0x{got:x}，期望 0x{expected:x} "
                f"(dr_in=0x{tr.dr_in:x})"
            )
            self.fail_cnt += 1

    def report_phase(self):
        """最终统计报告"""
        total = self.pass_cnt + self.fail_cnt
        self.logger.info(
            f"=== Scoreboard 结果: PASS={self.pass_cnt}  "
            f"FAIL={self.fail_cnt}  TOTAL={total} ==="
        )
        if self.fail_cnt > 0:
            self.logger.error("存在失败的检查项！")
        else:
            self.logger.info("所有检查通过！")
