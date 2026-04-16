# Simple RISC-V CPU - Agent Instructions

This document provides essential instructions, commands, and code style guidelines for AI coding agents operating in this repository.

## 1. Build and Test Commands

### Core Make Commands
The project uses `make` as the primary build and test system.

```bash
# Clean build artifacts
make clean

# Run all Verilog-only unit tests (alu, timer, gpio, etc.)
make unit-tests

# Run the single-file rv32i integration test
make integration-tests

# Run all rv32ui ISA regression tests (compliance)
make isa-regression

# Generate .mem files from riscv-tests (requires riscv-gnu-toolchain)
make gen-mem
```

### Running Single Tests (Crucial for Iteration)
When developing or debugging, run individual tests rather than the full suite:

```bash
# Run a single Verilog unit test (e.g., alu, control_unit, timer)
make _unit_alu
make _unit_timer

# Run a single ISA compliance test
make isa-test TEST=rv32ui-p-add
make isa-test TEST=rv32ui-p-bne

# Run a single Cocotb test (JTAG verification)
cd tb/cocotb && make MODULE=test_tap_fsm
cd tb/cocotb && make MODULE=test_debug_regs

# Run pyUVM JTAG simulation (requires Docker)
docker compose run --rm sim make -C tb/uvm sim
```

### Docker Environment
For Python-based testbenches (pyUVM/Cocotb) with dependencies, prefer running inside Docker:
```bash
docker compose build          # Build the simulation image
docker compose run --rm sim   # Open an interactive shell inside the container
```

## 2. Architecture & Directory Structure

*   `rtl/` - Core Verilog files (`riscv_core.v`, `alu.v`, `jtag_tap.v`, etc.).
*   `tb/unit/` - Basic Verilog testbenches for individual RTL modules.
*   `tb/integration/` - Full-core integration tests.
*   `tb/isa/` - RISC-V compliance testbench (`tb_isa_test.v`).
*   `tb/cocotb/` - Python-based Cocotb tests for JTAG and debug interfaces.
*   `tb/uvm/` - pyUVM verification environment.
*   `tests/isa/mem/` - Pre-compiled hex files (`*.mem`) for ISA compliance testing.

## 3. Code Style Guidelines

### Verilog (RTL & Testbenches)
1.  **Naming Conventions:**
    *   Modules, instances, wires, and registers: `snake_case` (e.g., `alu_control`, `pc_next`).
    *   Parameters and Localparams: `UPPER_SNAKE_CASE` (e.g., `OPCODE_R_TYPE`, `S_FETCH`).
    *   Active-low signals: Append `_n` (e.g., `rst_n`), though active-high `rst` is preferred in this project.
2.  **Formatting & Indentation:**
    *   Use 4 spaces or hardware tabs for indentation.
    *   Always use named port connections for module instantiations: `.port_name(signal_name)`. Do not use positional mapping.
    *   One port declaration per line in module headers.
3.  **Synthesizable Code Rules (RTL):**
    *   Separate combinatorial logic (`always @(*)`) from sequential logic (`always @(posedge clk)`).
    *   Always use non-blocking assignments (`<=`) in sequential blocks.
    *   Always use blocking assignments (`=`) in combinatorial blocks.
    *   Provide default values for all outputs in `always @(*)` blocks to prevent unwanted latches.
4.  **Types:**
    *   Explicitly declare all `wire` and `reg` types. Do not rely on implicit net declarations.
5.  **Comments:**
    *   Use inline comments `//` to explain *why* a complex operation is happening, not *what* it is doing.
    *   A brief block comment at the top of complex modules is recommended.
    *   Existing code may contain Chinese comments; preserve them. If adding new comments, use English.

### Python (Cocotb & pyUVM)
1.  **Naming:**
    *   Functions, variables, and test modules: `snake_case` (e.g., `test_tap_fsm.py`, `async def test_idcode(dut):`).
    *   Classes (especially UVM components): `PascalCase`.
2.  **Formatting:**
    *   Follow standard PEP 8 formatting.
    *   Use 4 spaces for indentation.
3.  **Cocotb Best Practices:**
    *   Always use `await` with timing triggers (e.g., `await RisingEdge(dut.clk)`, `await Timer(10, units='ns')`).
    *   Use `@cocotb.test()` decorators for test entry points.
    *   Keep test functions asynchronous (`async def`).
    *   Assert failures clearly with custom messages: `assert dut.val.value == expected, f"Expected {expected}, got {dut.val.value}"`.

### General Practices
1.  **Error Handling:** In testbenches, fail fast and print descriptive error messages using `$display` or `$error` (Verilog) or `dut._log.error` (Python).
2.  **No Magic Numbers:** Use `localparam` or `parameter` in Verilog, and constants in Python, instead of hardcoding values (especially for opcodes, addresses, and states).
3.  **Imports:** Group Python imports properly (Standard Library -> Third Party -> Local modules).
4.  **Self-Verification:** Before finalizing any task, you must run the relevant test suite (e.g., `make _unit_<module>`) to ensure changes are correct and don't break existing functionality.