#!/bin/bash

echo "--- Running Unit Tests ---"

# Function to compile and run a test
run_test() {
    NAME=$1
    TB_FILE=$2
    RTL_FILES=$3
    VVP_FILE="sim/tb_${NAME}.vvp"

    echo "--- Testing ${NAME} ---"
    iverilog -g2012 -o "${VVP_FILE}" "${TB_FILE}" ${RTL_FILES}
    if [ $? -ne 0 ]; then
        echo "COMPILATION FAILED for ${NAME}"
        return 1
    fi
    vvp "${VVP_FILE}"
    if [ $? -ne 0 ]; then
        echo "TEST FAILED for ${NAME}"
        return 1
    fi
    echo "--- ${NAME} Test Passed ---"
    rm "${VVP_FILE}"
    return 0
}

# Run tests
run_test "control_unit" "sim/tb_control_unit.v" "rtl/control_unit.v" && \
run_test "data_memory" "sim/tb_data_memory.v" "rtl/data_memory.v" && \
run_test "immediate_generator" "sim/tb_immediate_generator.v" "rtl/immediate_generator.v" && \
run_test "pc_register" "sim/tb_pc_register.v" "rtl/pc_register.v" && \
run_test "register_file" "sim/tb_register_file.v" "rtl/register_file.v" && \
run_test "timer" "sim/tb_timer.v" "rtl/timer.v"

if [ $? -eq 0 ]; then
    echo "--- All unit tests passed successfully! ---"
else
    echo "--- Some unit tests failed. ---"
fi
