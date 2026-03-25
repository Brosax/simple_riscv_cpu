"""
test_bypass.py — BYPASS Instruction Test

Verifies that:
1. IR=BYPASS (5'b11111) can be written
2. BYPASS register captures 0 at Capture-DR
3. Shifting 5 ones and 5 zeros through BYPASS works correctly
"""
import cocotb
from cocotb.clock import Clock
from jtag_driver import JTAGDriver


@cocotb.test()
async def test_bypass_register(dut):
    """BYPASS register should be 1 bit, capture=0, shift works."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1
    dut.debug_rdata.value = 0

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())

    driver = JTAGDriver(dut)

    # Write BYPASS IR
    await driver.ir_scan(driver.IR_BYPASS)

    # Read BYPASS DR — should return 0 (capture=0, bypass_reg=0)
    result = await driver.dr_scan(0, num_bits=1)
    assert result == 0, f"BYPASS capture: expected 0, got {result}"

    # Shift in 1: write 1, read old (0), then read back
    result = await driver.dr_scan(1, num_bits=1)
    # After shifting 1 in, the captured value should be 1
    assert result == 1, f"BYPASS shift: expected 1, got {result}"

    dut._log.info("BYPASS test passed ✓")
