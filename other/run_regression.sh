#!/bin/bash

# --- Configuration ---
TEST_DIR="test/isa/hex"
TEST_PATTERNS=("rv32ui-p-*.hex" "rv32mi-p-*.hex")
SIM_VVP="tb_riscv_core.vvp"
SIM_LOG="simulation.log"
SIG_LOG="signature.log"

# Counters
PASSED_COUNT=0
FAILED_COUNT=0
INCONCLUSIVE_COUNT=0
TOTAL_COUNT=0

# --- Compile RTL and Testbench ---
echo "================================================="
echo "COMPILING RTL AND TESTBENCH..."
echo "================================================="
iverilog -g2012 -o "$SIM_VVP" sim/tb_riscv_core.v rtl/*.v
if [ $? -ne 0 ]; then
    echo "COMPILATION FAILED. Aborting."
    exit 1
fi
echo "Compilation successful."
echo ""

# --- Run Regression ---
echo "================================================="
echo "RUNNING REGRESSION TESTS..."
echo "================================================="

# Find all test files
TEST_FILES=()
for pattern in "${TEST_PATTERNS[@]}"; do
    while IFS= read -r -d $'\0'; do
        TEST_FILES+=("$REPLY")
    done < <(find "$TEST_DIR" -name "$pattern" -print0)
done

# Loop through all tests
for test_hex in "${TEST_FILES[@]}"; do
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    test_name=$(basename "$test_hex" .hex)
    
    echo "Running test [$TOTAL_COUNT]: $test_name"

    # Define the reference dump file path
    test_dump="${TEST_DIR}/${test_name}.dump"

    # 1. Prepare test_program.txt
    echo "$test_hex" > test_program.txt

    # 2. Run simulation
    vvp "$SIM_VVP" > "$SIM_LOG" 2>&1

    # 3. Check results
    if [ -f "$SIG_LOG" ]; then
        # Signature file was created, compare it with the reference dump
        echo -n "  -> Comparing signature... "
        diff --color=always "$SIG_LOG" "$test_dump"
        if [ $? -eq 0 ]; then
            echo "SIGNATURE MATCH: PASS"
            PASSED_COUNT=$((PASSED_COUNT + 1))
        else
            echo "SIGNATURE MISMATCH: FAIL"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    else
        # No signature file, meaning the test failed to complete
        echo "  -> No signature generated. Test timed out or failed early: FAIL"
        INCONCLUSIVE_COUNT=$((INCONCLUSIVE_COUNT + 1))
        # Optional: show log for inconclusive tests
        # cat $SIM_LOG
    fi
    echo ""
done

# --- Summary ---
FAILED_TOTAL=$((FAILED_COUNT + INCONCLUSIVE_COUNT))
echo "================================================="
echo "REGRESSION SUMMARY"
echo "================================================="
echo "TOTAL TESTS: $TOTAL_COUNT"
echo -e "\e[32mPASSED:           $PASSED_COUNT\e[0m"
echo -e "\e[31mFAILED (Mismatch):  $FAILED_COUNT\e[0m"
echo -e "\e[33mFAILED (Timeout):   $INCONCLUSIVE_COUNT\e[0m"
echo "-------------------------------------------------"
if [ $FAILED_TOTAL -ne 0 ]; then
    echo -e "\e[31mOVERALL STATUS: FAIL\e[0m"
else
    echo -e "\e[32mOVERALL STATUS: PASS\e[0m"
fi
echo "================================================="

# --- Cleanup ---
rm -f test_program.txt "$SIM_VVP" "$SIM_LOG" "$SIG_LOG"

# Exit with a non-zero status code if any tests failed
if [ $FAILED_TOTAL -ne 0 ]; then
    exit 1
else
    exit 0
fi
