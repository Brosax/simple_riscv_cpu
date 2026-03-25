"""
test_debug_regs.py — Debug Register Read/Write Test

Verifies that:
1. Writing a GPR via DEBUG_ACCESS works
2. Reading it back returns the written value
3. x0 always reads back as 0
4. PC read returns a non-zero value (CPU running or halted)
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from jtag_driver import JTAGDriver


@cocotb.test()
async def test_debug_reg_write_read(dut):
    """Write and read back GPRs via DEBUG_ACCESS."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1

    # Start CPU clock
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())

    # Let CPU run for a few cycles first
    for _ in range(5):
        await RisingEdge(dut.clk)

    driver = JTAGDriver(dut)

    # Write x5 = 0xDEADBEEF
    result = await driver.write_register(5, 0xDEADBEEF)
    await RisingEdge(dut.clk)

    # Read back x5
    val = await driver.read_register(5)
    assert val == 0xDEADBEEF, f"x5: wrote 0xDEADBEEF, read 0x{val:08X}"
    dut._log.info(f"x5 write/read: 0x{val:08X} ✓")

    # Write x10 = 0x12345678
    await driver.write_register(10, 0x12345678)
    await RisingEdge(dut.clk)

    val = await driver.read_register(10)
    assert val == 0x12345678, f"x10: wrote 0x12345678, read 0x{val:08X}"
    dut._log.info(f"x10 write/read: 0x{val:08X} ✓")

    # Write x0 = 0xDEADBEEF (should still be 0)
    await driver.write_register(0, 0xDEADBEEF)
    await RisingEdge(dut.clk)

    val = await driver.read_register(0)
    assert val == 0, f"x0 should always be 0, got 0x{val:08X}"
    dut._log.info("x0 is always 0 ✓")

    # Read PC
    pc = await driver.read_pc()
    dut._log.info(f"PC read: 0x{pc:08X}")
    assert pc != 0, "PC should not be zero"


@cocotb.test()
async def test_debug_multiple_registers(dut):
    """Write many registers, verify no cross-contamination."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    for _ in range(3):
        await RisingEdge(dut.clk)

    driver = JTAGDriver(dut)

    # Write each register with a unique value
    test_values = {i: 0x11111111 * i for i in range(1, 16)}

    for idx, val in test_values.items():
        await driver.write_register(idx, val)
        await RisingEdge(dut.clk)

    # Read all back and verify
    for idx, expected in test_values.items():
        actual = await driver.read_register(idx)
        assert actual == expected, \
            f"x{idx}: expected 0x{expected:08X}, got 0x{actual:08X}"

    dut._log.info(f"Wrote and verified {len(test_values)} registers ✓")
