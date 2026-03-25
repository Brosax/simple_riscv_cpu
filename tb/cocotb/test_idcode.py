"""
test_idcode.py — IDCODE Register Read Test

Verifies that:
1. IR=IDCODE (5'b00001) can be written
2. Reading DR while IR=IDCODE returns 0x00000001
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from jtag_driver import JTAGDriver


@cocotb.test()
async def test_idcode_value(dut):
    """Read IDCODE via JTAG."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1
    dut.debug_rdata.value = 0

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())

    # Manually do IR scan: go to SHIFT_IR, shift in IDCODE=0b00001, exit
    # Path: RTI(0) → SelDR(1) → SelIR(1) → CapIR(0) → ShiftIR(0)
    tms_seq = [1, 0, 1, 1, 0, 0]
    for t in tms_seq:
        dut.jtag_tms.value = t
        dut.jtag_tck.value = 1
        await Timer(2, unit="ns")
        dut.jtag_tck.value = 0
        await Timer(2, unit="ns")

    # Now in SHIFT_IR. Check what TDO outputs during this state.
    # IR capture is 0b00001. First TDO should be 1.
    tdo_at_shift_ir_enter = int(dut.jtag_tdo.value)
    dut._log.info(f"TDO right after entering SHIFT_IR: {tdo_at_shift_ir_enter}")

    # Shift 5 bits of IR=0b00001 (LSB first), TMS=0 to stay in SHIFT, last=1 to exit
    ir_val = 0b00001
    result = 0
    for i in range(5):
        dut.jtag_tdi.value = (ir_val >> i) & 1
        dut.jtag_tms.value = 1  # exit after last bit
        dut.jtag_tck.value = 1
        await Timer(2, unit="ns")
        try:
            tdo_bit = int(dut.jtag_tdo.value)
        except Exception:
            tdo_bit = 0
        result |= (tdo_bit << i)
        dut._log.info(f"  IR shift bit[{i}]: tdi={dut.jtag_tdi.value.integer}, tdo={tdo_bit}")
        dut.jtag_tck.value = 0
        await Timer(2, unit="ns")

    dut._log.info(f"IR capture result: 0b{result:05b} = {result}")
    assert result == ir_val, f"IR mismatch: wrote 0b{ir_val:05b}, read 0b{result:05b}"

    # UPDATE_IR: Exit1IR=1, UpdateIR=0, RTI=0
    upd_seq = [1, 1, 0]
    for t in upd_seq:
        dut.jtag_tms.value = t
        dut.jtag_tck.value = 1
        await Timer(2, unit="ns")
        dut.jtag_tck.value = 0
        await Timer(2, unit="ns")

    # SHIFT_DR: SelDR=1, CapDR=0, ShiftDR=0
    dr_seq = [1, 0, 0]
    for t in dr_seq:
        dut.jtag_tms.value = t
        dut.jtag_tck.value = 1
        await Timer(2, unit="ns")
        dut.jtag_tck.value = 0
        await Timer(2, unit="ns")

    # Check TDO at SHIFT_DR entry (should reflect captured IDCODE)
    tdo_at_shift_dr = int(dut.jtag_tdo.value)
    dut._log.info(f"TDO right after entering SHIFT_DR: {tdo_at_shift_dr}")

    # Read 32 bits IDCODE
    idcode_result = 0
    for i in range(32):
        dut.jtag_tdi.value = 0
        dut.jtag_tms.value = 1
        dut.jtag_tck.value = 1
        await Timer(2, unit="ns")
        try:
            tdo_bit = int(dut.jtag_tdo.value)
        except Exception:
            tdo_bit = 0
        idcode_result |= (tdo_bit << i)
        dut.jtag_tck.value = 0
        await Timer(2, unit="ns")

    dut._log.info(f"IDCODE read: 0x{idcode_result:08X}")
    assert idcode_result == 0x00000001, \
        f"IDCODE: expected 0x00000001, got 0x{idcode_result:08X}"
    dut._log.info("IDCODE test passed ✓")
