"""
jtag_monitor.py — UVMMonitor
被动观察 JTAG 总线信号，通过 TMS/TDI/TDO 重建 JtagTransaction，
并通过 analysis port 广播给 scoreboard。

观察策略：
  - 检测 TCK 上升沿
  - 跟踪 TMS 序列，识别 SHIFT_IR / SHIFT_DR 状态
  - 采集 IR 和 DR 的 TDI（移入）和 TDO（移出）bit 流
"""
import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import UVMMonitor, UVMAnalysisPort, ConfigDB
from jtag_transaction import JtagTransaction, IR_IDCODE, IR_BYPASS


class JtagMonitor(UVMMonitor):
    """
    UVM Monitor：观察 JTAG 信号，重建事务并写入 analysis port。
    """

    def build_phase(self):
        self.dut = ConfigDB().get(self, "", "DUT")
        # analysis port：连接到 scoreboard
        self.ap = UVMAnalysisPort("ap", self)
        # TAP 状态跟踪（软件模型）
        self._state = "RESET"
        self._ir    = IR_IDCODE  # 上次 UPDATE-IR 锁存的指令

    async def run_phase(self):
        """主循环：持续观察 TCK 上升沿，跟踪 TAP 状态"""
        while True:
            tr = await self._collect_one_transaction()
            if tr is not None:
                self.logger.debug(f"Monitor 采样: {tr}")
                self.ap.write(tr)

    # ------------------------------------------------------------------
    # 收集一笔完整事务（IR 扫描 + DR 扫描）
    # ------------------------------------------------------------------
    async def _collect_one_transaction(self) -> JtagTransaction:
        # 等待 SHIFT_IR，收集 IR 位流
        ir_bits = await self._wait_and_collect_shift_ir()
        # 等待 SHIFT_DR，收集 DR 位流
        dr_tdi_bits, dr_tdo_bits, bit_cnt = await self._wait_and_collect_shift_dr()

        tr = JtagTransaction("mon_tr")
        tr.ir      = ir_bits
        tr.dr_in   = dr_tdi_bits
        tr.dr_out  = dr_tdo_bits
        tr.dr_bits = bit_cnt
        return tr

    # ------------------------------------------------------------------
    # 等待并采集 SHIFT_IR 阶段的 IR 位流
    # 识别方式：从 RTI 出发的 TMS 序列 1-1-0-0 进入 SHIFT_IR
    # ------------------------------------------------------------------
    async def _wait_and_collect_shift_ir(self) -> int:
        # 用小型 TAP 状态机跟踪，直到进入 SHIFT_IR
        state = self._state
        while True:
            await RisingEdge(self.dut.jtag_tck)
            tms = int(self.dut.jtag_tms.value)
            state = self._next_state(state, tms)
            if state == "SHIFT_IR":
                break

        # 进入 SHIFT_IR，逐 bit 采集，直到 TMS=1（EXIT1_IR）
        ir_bits = 0
        bit_idx = 0
        while True:
            await RisingEdge(self.dut.jtag_tck)
            tms = int(self.dut.jtag_tms.value)
            try:
                tdi = int(self.dut.jtag_tdi.value)
            except ValueError:
                tdi = 0
            ir_bits |= (tdi << bit_idx)
            bit_idx += 1
            state = self._next_state(state, tms)
            if tms == 1:  # EXIT1_IR
                break

        # 跟踪到 UPDATE_IR 并锁存
        while state != "UPDATE_IR":
            await RisingEdge(self.dut.jtag_tck)
            tms = int(self.dut.jtag_tms.value)
            state = self._next_state(state, tms)
        self._ir    = ir_bits & 0x1F
        self._state = state
        return self._ir

    # ------------------------------------------------------------------
    # 等待并采集 SHIFT_DR 阶段的 DR TDI/TDO 位流
    # ------------------------------------------------------------------
    async def _wait_and_collect_shift_dr(self):
        state = self._state
        while True:
            await RisingEdge(self.dut.jtag_tck)
            tms = int(self.dut.jtag_tms.value)
            state = self._next_state(state, tms)
            if state == "SHIFT_DR":
                break

        dr_tdi = 0
        dr_tdo = 0
        bit_idx = 0
        while True:
            await RisingEdge(self.dut.jtag_tck)
            tms = int(self.dut.jtag_tms.value)
            try:
                tdi = int(self.dut.jtag_tdi.value)
            except ValueError:
                tdi = 0
            try:
                tdo = int(self.dut.jtag_tdo.value)
            except ValueError:
                tdo = 0
            dr_tdi |= (tdi << bit_idx)
            dr_tdo |= (tdo << bit_idx)
            bit_idx += 1
            state = self._next_state(state, tms)
            if tms == 1:  # EXIT1_DR
                break

        self._state = state
        return dr_tdi, dr_tdo, bit_idx

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
