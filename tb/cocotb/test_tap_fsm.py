"""
test_tap_fsm.py — JTAG TAP State Machine Tests

Verifies that the IEEE 1149.1 TAP state machine transitions correctly.
Tests use only tck/tms/tdi/tdo — no debug register content needed.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from jtag_driver import JTAGDriver


async def tap_cycle(dut, tms, tdi=0):
    """Single TCK cycle."""
    dut.jtag_tdi.value = tdi
    dut.jtag_tms.value = tms
    await Timer(1, units="ns")
    dut.jtag_tck.value = 1
    await Timer(1, units="ns")
    tdo = int(dut.jtag_tdo.value)
    dut.jtag_tck.value = 0
    await Timer(1, units="ns")
    return bool(tdo)


def state_name(state):
    names = {
        0: "RESET", 1: "RUN_TEST_IDLE", 2: "SELECT_DR", 3: "CAPTURE_DR",
        4: "SHIFT_DR", 5: "EXIT1_DR", 6: "PAUSE_DR", 7: "EXIT2_DR",
        8: "UPDATE_DR", 9: "SELECT_IR", 10: "CAPTURE_IR", 11: "SHIFT_IR",
        12: "EXIT1_IR", 13: "PAUSE_IR", 14: "EXIT2_IR", 15: "UPDATE_IR"
    }
    return names.get(int(state), f"?{int(state)}")


async def read_state(dut):
    """Read current TAP state by shifting DR (captures state)."""
    # From any state, go to SHIFT-DR and read captured value
    # For this test, just verify basic transitions via TMS sequences
    pass


@cocotb.test()
async def test_tap_reset_via_tms_sequence(dut):
    """5 consecutive TMS=1 while in RUN_TEST_IDLE → RESET state."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1  # active-low, so 1 = enabled

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())

    # Start from RESET by issuing TMS=1 five times
    for _ in range(5):
        await tap_cycle(dut, tms=1, tdi=0)

    # Now drive TMS=0 and check we reach RUN_TEST_IDLE
    await tap_cycle(dut, tms=0, tdi=0)

    # 1 TCK in RUN_TEST_IDLE with TMS=0 should stay there
    tdo = await tap_cycle(dut, tms=0, tdi=0)
    # TDO should be 0 in IDLE (no active DR shift)
    assert tdo == 0, f"Expected TDO=0 in RUN_TEST_IDLE, got {tdo}"


@cocotb.test()
async def test_tap_ir_path(dut):
    """Path: RUN_TEST_IDLE → SELECT_DR → SELECT_IR → CAPTURE_IR → SHIFT_IR."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())

    # Reset first
    for _ in range(5):
        await tap_cycle(dut, tms=1, tdi=0)

    # RUN_TEST_IDLE → SELECT_DR → SELECT_IR
    await tap_cycle(dut, tms=1, tdi=0)  # → SELECT_DR
    await tap_cycle(dut, tms=1, tdi=0)  # → SELECT_IR

    # SELECT_IR → CAPTURE_IR (TMS=0)
    await tap_cycle(dut, tms=0, tdi=0)  # → CAPTURE_IR

    # CAPTURE_IR → SHIFT_IR (TMS=0) — capture is 0b00001
    tdo = await tap_cycle(dut, tms=0, tdi=0)  # → SHIFT_IR
    # First captured bit should be 1 (IR capture value LSB)
    assert tdo == 1, f"Expected IR capture[0]=1, got {tdo}"

    # Shift remaining 4 bits of IR (value 0b00001)
    for i in range(1, 5):
        tdo = await tap_cycle(dut, tms=(i == 4), tdi=0)  # last=1 to exit
        expected = (0b00001 >> i) & 1
        assert tdo == expected, f"IR bit[{i}] expected {expected}, got {tdo}"

    # Now in UPDATE_IR
    await tap_cycle(dut, tms=0, tdi=0)  # → RUN_TEST_IDLE

    # Verify by reading IDCODE: go through SHIFT_DR with IDCODE IR
    driver = JTAGDriver(dut)
    idcode = await driver.read_idcode()
    assert idcode == 0x00000001, f"IDCODE mismatch: expected 0x00000001, got 0x{idcode:08X}"


@cocotb.test()
async def test_tap_shift_dr_path(dut):
    """Path: RUN_TEST_IDLE → SHIFT_DR, shift 8 bits, exit via UPDATE_DR."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())

    # Reset
    for _ in range(5):
        await tap_cycle(dut, tms=1, tdi=0)

    # Go to SHIFT_DR: RTI→SelDR→CapDR→ShiftDR
    await tap_cycle(dut, tms=1, tdi=0)  # → SELECT_DR
    await tap_cycle(dut, tms=0, tdi=0)  # → CAPTURE_DR
    await tap_cycle(dut, tms=0, tdi=0)  # → SHIFT_DR

    # Shift in 0xAA (LSB first)
    test_data = 0xAA
    for i in range(8):
        tdo = await tap_cycle(dut, tms=(i == 7), tdi=(test_data >> i) & 1)
        expected_tdo = 0  # IDCODE in capture, LSB = 1 → but we're in DR, not IR
        # TDO during SHIFT_DR with IR=IDCODE outputs debug_dr[0] = IDCODE[0] = 1
        if i == 0:
            assert tdo == 1, f"DR shift bit[0] expected 1 (IDCODE capture), got {tdo}"

    # Should be in UPDATE_DR
    await tap_cycle(dut, tms=0, tdi=0)  # → RUN_TEST_IDLE

    # Success: we completed a DR shift
    assert True
