"""
JTAG Driver for RISC-V JTAG TAP Controller
Uses cocotb RisingEdge/FallingEdge for correct edge alignment.
"""

from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
from cocotb.types import LogicArray
import cocotb


class JTAGDriver:
    IR_IDCODE        = 0b00001
    IR_BYPASS        = 0b11111
    IR_DEBUG_ACCESS  = 0b10110
    IR_DEBUG_RESET   = 0b11010

    def __init__(self, dut):
        self.dut = dut
        # Track previous TCK to detect edges manually (since JTAG doesn't use dut.clk)
        self._tck_prev = 0

    # -------------------------------------------------------------------------
    # Low-level primitives using edge detection
    # -------------------------------------------------------------------------

    async def _pulse_tck(self):
        """Drive one full TCK low→high→low cycle."""
        self.dut.jtag_tck.value = 1
        await Timer(1, unit="ns")
        self.dut.jtag_tck.value = 0
        await Timer(1, unit="ns")

    async def _tap_cycle(self, tms: int, tdi: int) -> int:
        """
        One complete TCK cycle: set TDI/TMS, pulse TCK, return TDO at rising edge.
        Uses Timer delays (not RisingEdge) for compatibility with VPI on TCK.
        """
        self.dut.jtag_tdi.value = tdi
        self.dut.jtag_tms.value = tms
        await Timer(1, unit="ns")
        # Rising edge of TCK: TAP samples TDI and updates state
        self.dut.jtag_tck.value = 1
        await Timer(2, unit="ns")
        # TDO is valid at/internally within this clock edge
        try:
            tdo = int(self.dut.jtag_tdo.value)
        except ValueError:
            tdo = 0  # unresolved ('X') → treat as 0
        # Falling edge
        self.dut.jtag_tck.value = 0
        await Timer(2, unit="ns")
        return tdo

    async def _shift_n_bits(self, value: int, num_bits: int, tms_end: int = 1) -> int:
        """Shift num_bits LSB-first, return captured bits as int."""
        result = 0
        for i in range(num_bits):
            tdi_bit = (value >> i) & 1
            tms_bit = tms_end if (i == num_bits - 1) else 0
            tdo_bit = await self._tap_cycle(tms=tms_bit, tdi=tdi_bit)
            result |= (tdo_bit << i)
        return result

    async def _go_to_state(self, state_name: str):
        """Move TAP to named state via TMS sequences."""
        path_map = {
            "RESET":         [1, 1, 1, 1, 1],
            "RUN_TEST_IDLE": [0],
            "SHIFT_DR":      [1, 0, 0],
            "UPDATE_DR":     [1, 1, 0],
            "SHIFT_IR":      [1, 1, 0, 0],
            "UPDATE_IR":     [1, 1, 0, 1, 0],
        }
        seq = path_map[state_name]
        for tms in seq:
            await self._tap_cycle(tms, 0)

    # -------------------------------------------------------------------------
    # IR scan
    # -------------------------------------------------------------------------

    async def ir_scan(self, ir_value: int) -> int:
        """Write 5-bit IR LSB-first, return captured 5 bits."""
        await self._go_to_state("SHIFT_IR")
        cap = await self._shift_n_bits(ir_value, 5)
        await self._go_to_state("UPDATE_IR")
        await self._go_to_state("RUN_TEST_IDLE")
        return cap

    # -------------------------------------------------------------------------
    # DR scan
    # -------------------------------------------------------------------------

    async def dr_scan(self, dr_value: int, num_bits: int = 47) -> int:
        """Write num_bits into DR LSB-first, return captured bits."""
        await self._go_to_state("SHIFT_DR")
        cap = await self._shift_n_bits(dr_value, num_bits)
        await self._go_to_state("UPDATE_DR")
        await self._go_to_state("RUN_TEST_IDLE")
        return cap

    # -------------------------------------------------------------------------
    # High-level helpers
    # -------------------------------------------------------------------------

    async def read_idcode(self) -> int:
        """Read IDCODE: IR=IDCODE, DR=32 bits → 0x00000001."""
        await self.ir_scan(self.IR_IDCODE)
        result = await self.dr_scan(0, num_bits=32)
        return result

    async def read_bypass(self) -> int:
        """Read BYPASS register (1 bit)."""
        await self.ir_scan(self.IR_BYPASS)
        return await self.dr_scan(0, num_bits=1)

    async def write_debug_reg(self, op: int, type_: int, addr: int, data: int) -> int:
        """Read/write debug register via DEBUG_ACCESS."""
        await self.ir_scan(self.IR_DEBUG_ACCESS)
        dr_value = (op << 46) | (type_ << 45) | ((addr & 0x1FFF) << 32) | (data & 0xFFFFFFFF)
        result = await self.dr_scan(dr_value, num_bits=47)
        return result & 0xFFFFFFFF

    async def read_register(self, reg_idx: int) -> int:
        return await self.write_debug_reg(op=0, type_=0, addr=reg_idx, data=0)

    async def write_register(self, reg_idx: int, value: int) -> int:
        return await self.write_debug_reg(op=1, type_=0, addr=reg_idx, data=value)

    async def read_pc(self) -> int:
        return await self.write_debug_reg(op=0, type_=0, addr=0x20, data=0)

    async def read_status(self) -> int:
        return await self.write_debug_reg(op=0, type_=0, addr=0x21, data=0)

    async def resume_cpu(self) -> int:
        await self.ir_scan(self.IR_DEBUG_RESET)
        dr_value = (1 << 46) | (0 << 45) | (0x22 << 32) | 1
        return await self.dr_scan(dr_value, num_bits=47)

    async def read_memory(self, addr_words: int) -> int:
        return await self.write_debug_reg(op=0, type_=1, addr=addr_words, data=0)

    async def write_memory(self, addr_words: int, value: int) -> int:
        return await self.write_debug_reg(op=1, type_=1, addr=addr_words, data=value)
