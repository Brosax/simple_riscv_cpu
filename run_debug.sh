#!/bin/bash

# --- Configuration ---
TEST_DIR="tests/riscv-tests/isa"
TEST_NAME="rv32ui-p-addi"
TEST_HEX="${TEST_DIR}/${TEST_NAME}.hex"
SIM_VVP="tb_riscv_core.vvp"

echo "================================================="
echo "COMPILING FOR DEBUG..."
echo "================================================="
iverilog -g2012 -o "$SIM_VVP" sim/tb_riscv_core.v rtl/*.v
if [ $? -ne 0 ]; then
    echo "COMPILATION FAILED. Aborting."
    exit 1
fi
echo "Compilation successful."
echo ""

echo "================================================="
echo "RUNNING DEBUG SIMULATION for ${TEST_NAME}"
echo "================================================="

# 1. Prepare test_program.txt
echo "$TEST_HEX" > test_program.txt

# 2. Run simulation
vvp "$SIM_VVP"

echo "================================================="
echo "Debug simulation finished."
echo "Waveform file 'tb_riscv_core.vcd' has been generated."
echo "You can analyze it with a waveform viewer like GTKWave."
echo "================================================="

# Cleanup
rm -f test_program.txt "$SIM_VVP"
