"""
jtag_monitor.py — uvm_monitor
被动观察 JTAG 总线信号，通过 TMS/TDI/TDO 重建 JtagTransaction，
并通过 uvm_analysis_port 广播给 scoreboard。

观察策略：
  - 检测 TCK 上升沿
  - 用软件 TAP 状态机跟踪 TMS 序列
  - 识别 SHIFT_IR / SHIFT_DR 状态，采集 TDI/TDO 位流
"""
from cocotb.triggers import RisingEdge
from pyuvm import uvm_monitor, uvm_analysis_port, ConfigDB

from jtag_transaction import JtagTransaction, IR_IDCODE


class JtagMonitor(uvm_monitor):
    """
    UVM Monitor：观察 JTAG 信号，重建事务并写入 analysis port。
    """

    def build_phase(self):
        self.dut   = ConfigDB().get(self, "", "DUT")
        # analysis port：写入采样到的事务，供 scoreboard 消费
        self.ap    = uvm_analysis_port("ap", self)
        # 当前 TAP 状态（软件跟踪）
        self._state = "RESET"
        # 上一次 UPDATE_IR 锁存的 IR 值
        self._ir    = IR_IDCODE

    async def run_phase(self):
        """主循环：持续采集事务"""
        while True:
            tr = await self._collect_one_transaction()
            if tr is not None:
                self.logger.debug(f"Monitor 采样: {tr}")
                self.ap.write(tr)

    # ------------------------------------------------------------------
    # 收集一笔完整事务（IR 扫描 + DR 扫描）
    # ------------------------------------------------------------------
    async def _collect_one_transaction(self):
        ir_val = await self._wait_shift_ir()
        dr_tdi, dr_tdo, bit_cnt = await self._wait_shift_dr()

        tr           = JtagTransaction("mon_tr")
        tr.ir        = ir_val
        tr.dr_in     = dr_tdi
        tr.dr_out    = dr_tdo
        tr.dr_bits   = bit_cnt
        return tr

    # ------------------------------------------------------------------
    # 等待并采集 SHIFT_IR 的 TDI 位流，直到 UPDATE_IR
    # ------------------------------------------------------------------
    async def _wait_shift_ir(self) -> int:
        state = self._state
        # 等待进入 SHIFT_IR
        while state != "SHIFT_IR":
            await RisingEdge(self.dut.jtag_tck)
            tms   = self._safe_read(self.dut.jtag_tms)
            state = self._next_state(state, tms)

        # 逐 bit 采集，直到 TMS=1（EXIT1_IR）
        ir_bits = 0
        bit_idx = 0
        while True:
            await RisingEdge(self.dut.jtag_tck)
            tms = self._safe_read(self.dut.jtag_tms)
            tdi = self._safe_read(self.dut.jtag_tdi)
            ir_bits |= (tdi << bit_idx)
            bit_idx  += 1
            state     = self._next_state(state, tms)
            if tms == 1:   # EXIT1_IR
                break

        # 跟踪到 UPDATE_IR
        while state != "UPDATE_IR":
            await RisingEdge(self.dut.jtag_tck)
            tms   = self._safe_read(self.dut.jtag_tms)
            state = self._next_state(state, tms)

        self._ir    = ir_bits & 0x1F
        self._state = state
        return self._ir

    # ------------------------------------------------------------------
    # 等待并采集 SHIFT_DR 的 TDI/TDO 位流，直到 EXIT1_DR
    # ------------------------------------------------------------------
    async def _wait_shift_dr(self):
        state = self._state
        while state != "SHIFT_DR":
            await RisingEdge(self.dut.jtag_tck)
            tms   = self._safe_read(self.dut.jtag_tms)
            state = self._next_state(state, tms)

        dr_tdi  = 0
        dr_tdo  = 0
        bit_idx = 0
        while True:
            await RisingEdge(self.dut.jtag_tck)
            tms = self._safe_read(self.dut.jtag_tms)
            tdi = self._safe_read(self.dut.jtag_tdi)
            tdo = self._safe_read(self.dut.jtag_tdo)
            dr_tdi  |= (tdi << bit_idx)
            dr_tdo  |= (tdo << bit_idx)
            bit_idx  += 1
            state     = self._next_state(state, tms)
            if tms == 1:   # EXIT1_DR
                break

        self._state = state
        return dr_tdi, dr_tdo, bit_idx

    # ------------------------------------------------------------------
    # 辅助：安全读取信号（X/Z → 0）
    # ------------------------------------------------------------------
    @staticmethod
    def _safe_read(signal) -> int:
        try:
            return int(signal.value)
        except ValueError:
            return 0

    # ------------------------------------------------------------------
    # TAP 状态机转移表（IEEE 1149.1）
    # ------------------------------------------------------------------
    _TRANSITIONS = {
        "RESET":     {0: "RTI",       1: "RESET"},
        "RTI":       {0: "RTI",       1: "SEL_DR"},
        "SEL_DR":    {0: "CAP_DR",    1: "SEL_IR"},
        "CAP_DR":    {0: "SHIFT_DR",  1: "EXIT1_DR"},
        "SHIFT_DR":  {0: "SHIFT_DR",  1: "EXIT1_DR"},
        "EXIT1_DR":  {0: "PAUSE_DR",  1: "UPDATE_DR"},
        "PAUSE_DR":  {0: "PAUSE_DR",  1: "EXIT2_DR"},
        "EXIT2_DR":  {0: "SHIFT_DR",  1: "UPDATE_DR"},
        "UPDATE_DR": {0: "RTI",       1: "SEL_DR"},
        "SEL_IR":    {0: "CAP_IR",    1: "RESET"},
        "CAP_IR":    {0: "SHIFT_IR",  1: "EXIT1_IR"},
        "SHIFT_IR":  {0: "SHIFT_IR",  1: "EXIT1_IR"},
        "EXIT1_IR":  {0: "PAUSE_IR",  1: "UPDATE_IR"},
        "PAUSE_IR":  {0: "PAUSE_IR",  1: "EXIT2_IR"},
        "EXIT2_IR":  {0: "SHIFT_IR",  1: "UPDATE_IR"},
        "UPDATE_IR": {0: "RTI",       1: "SEL_DR"},
    }

    def _next_state(self, state: str, tms: int) -> str:
        return self._TRANSITIONS.get(state, {}).get(tms, "RESET")
