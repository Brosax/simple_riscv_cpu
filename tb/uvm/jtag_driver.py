"""
jtag_driver.py — uvm_driver
将 JtagTransaction 转换为 TCK/TMS/TDI 信号时序，驱动 DUT。
TAP 状态机遵循 IEEE 1149.1，在 TCK 低电平期间设置信号，TCK 上升沿采样 TDO。
"""
from cocotb.triggers import Timer
from pyuvm import uvm_driver, ConfigDB

from jtag_transaction import JtagTransaction


# TCK 半周期（ns）
TCK_HALF = 10


class JtagDriver(uvm_driver):
    """
    UVM Driver：从 sequencer 取出 JtagTransaction，
    通过 cocotb 信号接口驱动 JTAG TAP。
    """

    def build_phase(self):
        # 从配置数据库获取 DUT handle（由 cocotb 入口注册）
        self.dut = ConfigDB().get(self, "", "DUT")

    async def run_phase(self):
        """主循环：先复位 TAP，再持续从 sequencer 取 item 驱动"""
        await self._do_reset()
        while True:
            tr = await self.seq_item_port.get_next_item()
            self.logger.info(f"驱动事务: {tr}")
            await self._drive_transaction(tr)
            self.seq_item_port.item_done()

    # ------------------------------------------------------------------
    # 复位：拉低 TRST_N 几个周期后释放，再发 TMS=0 进入 RUN_TEST_IDLE
    # ------------------------------------------------------------------
    async def _do_reset(self):
        self.dut.jtag_trst_n.value = 0
        self.dut.jtag_tms.value    = 1
        self.dut.jtag_tdi.value    = 0
        self.dut.jtag_tck.value    = 0
        await Timer(4 * 2 * TCK_HALF, units="ns")
        self.dut.jtag_trst_n.value = 1
        # TMS=0：进入 RUN_TEST_IDLE
        await self._tck_cycle(tms=0, tdi=0)

    # ------------------------------------------------------------------
    # 驱动一笔事务：先扫描 IR，再扫描 DR
    # ------------------------------------------------------------------
    async def _drive_transaction(self, tr: JtagTransaction):
        await self._scan_ir(tr.ir)
        tr.dr_out = await self._scan_dr(tr.dr_in, tr.dr_bits)

    # ------------------------------------------------------------------
    # IR 扫描（5 位，LSB first）
    # 路径：RTI → SEL_DR → SEL_IR → CAP_IR → SHIFT_IR(×5)
    #         → EXIT1_IR → UPD_IR → RTI
    # ------------------------------------------------------------------
    async def _scan_ir(self, ir_val: int):
        await self._tck_cycle(tms=1, tdi=0)  # RTI    → SEL_DR
        await self._tck_cycle(tms=1, tdi=0)  # SEL_DR → SEL_IR
        await self._tck_cycle(tms=0, tdi=0)  # SEL_IR → CAP_IR
        await self._tck_cycle(tms=0, tdi=0)  # CAP_IR → SHIFT_IR
        for i in range(5):
            tdi_bit = (ir_val >> i) & 1
            tms_bit = 1 if i == 4 else 0    # 最后一位 TMS=1 退出
            await self._tck_cycle(tms=tms_bit, tdi=tdi_bit)
        await self._tck_cycle(tms=1, tdi=0)  # EXIT1_IR → UPD_IR
        await self._tck_cycle(tms=0, tdi=0)  # UPD_IR   → RTI

    # ------------------------------------------------------------------
    # DR 扫描（dr_bits 位，LSB first），返回 TDO 采样值
    # 路径：RTI → SEL_DR → CAP_DR → SHIFT_DR(×N)
    #         → EXIT1_DR → UPD_DR → RTI
    # ------------------------------------------------------------------
    async def _scan_dr(self, dr_in: int, dr_bits: int) -> int:
        await self._tck_cycle(tms=1, tdi=0)  # RTI    → SEL_DR
        await self._tck_cycle(tms=0, tdi=0)  # SEL_DR → CAP_DR
        await self._tck_cycle(tms=0, tdi=0)  # CAP_DR → SHIFT_DR
        dr_out = 0
        for i in range(dr_bits):
            tdi_bit = (dr_in >> i) & 1
            tms_bit = 1 if i == dr_bits - 1 else 0
            tdo_bit = await self._tck_cycle(tms=tms_bit, tdi=tdi_bit)
            dr_out |= (tdo_bit << i)
        await self._tck_cycle(tms=1, tdi=0)  # EXIT1_DR → UPD_DR
        await self._tck_cycle(tms=0, tdi=0)  # UPD_DR   → RTI
        return dr_out

    # ------------------------------------------------------------------
    # 单个 TCK 周期：设置 TMS/TDI → 拉高 TCK → 采样 TDO → 拉低 TCK
    # ------------------------------------------------------------------
    async def _tck_cycle(self, tms: int, tdi: int) -> int:
        self.dut.jtag_tms.value = tms
        self.dut.jtag_tdi.value = tdi
        await Timer(TCK_HALF, units="ns")
        self.dut.jtag_tck.value = 1
        await Timer(TCK_HALF, units="ns")
        try:
            tdo = int(self.dut.jtag_tdo.value)
        except ValueError:
            tdo = 0  # X/Z 值视为 0
        self.dut.jtag_tck.value = 0
        await Timer(TCK_HALF, units="ns")
        return tdo
