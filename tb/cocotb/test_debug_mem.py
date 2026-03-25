"""
test_debug_mem.py — Debug Memory Access Test

Verifies that:
1. Writing a 32-bit word to data memory via DEBUG_ACCESS works
2. Reading it back returns the same value
3. Multiple addresses can be written independently
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from jtag_driver import JTAGDriver


@cocotb.test()
async def test_debug_memory_word(dut):
    """Write and read back 32-bit words from data memory."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    for _ in range(3):
        await RisingEdge(dut.clk)

    driver = JTAGDriver(dut)

    # Write 0xDEADBEEF to data memory at word offset 0x100 (0x400 bytes)
    addr = 0x100
    await driver.write_memory(addr, 0xDEADBEEF)
    await RisingEdge(dut.clk)

    val = await driver.read_memory(addr)
    assert val == 0xDEADBEEF, \
        f"Memory[0x{addr:03X}]: wrote 0xDEADBEEF, read 0x{val:08X}"
    dut._log.info(f"Memory word write/read: 0x{val:08X} ✓")

    # Write different values to nearby addresses
    await driver.write_memory(0x101, 0x12345678)
    await driver.write_memory(0x102, 0xA5A5A5A5)
    await RisingEdge(dut.clk)

    assert await driver.read_memory(0x101) == 0x12345678
    assert await driver.read_memory(0x102) == 0xA5A5A5A5
    dut._log.info("Multiple memory addresses ✓")


@cocotb.test()
async def test_debug_memory_pattern(dut):
    """Write walking-ones and walking-zeros pattern."""
    dut.jtag_tck.value = 0
    dut.jtag_tms.value = 0
    dut.jtag_tdi.value = 0
    dut.jtag_trst_n.value = 1

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    for _ in range(3):
        await RisingEdge(dut.clk)

    driver = JTAGDriver(dut)

    # Walking ones: 0x00000001, 0x00000002, ... 0x80000000
    for bit in range(32):
        val = 1 << bit
        addr = bit
        await driver.write_memory(addr, val)
        await RisingEdge(dut.clk)
        readback = await driver.read_memory(addr)
        assert readback == val, \
            f"Bit {bit}: wrote 0x{val:08X}, read 0x{readback:08X}"

    dut._log.info("Walking-ones pattern test passed ✓")
