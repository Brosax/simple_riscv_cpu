#!/bin/bash
# Runs all rv32ui ISA regression tests and prints a summary.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VVP_FILE="$PROJECT_ROOT/build/tb_isa_test.vvp"
MEM_DIR="$PROJECT_ROOT/tests/isa/mem"

if [ ! -f "$VVP_FILE" ]; then
    echo "ERROR: $VVP_FILE not found. Run 'make build/tb_isa_test.vvp' first."
    exit 1
fi

if [ ! -d "$MEM_DIR" ] || [ -z "$(ls "$MEM_DIR"/*.mem 2>/dev/null)" ]; then
    echo "ERROR: No .mem files in $MEM_DIR. Run 'make gen-mem' first."
    exit 1
fi

PASSED=0
FAILED=0
TOTAL=0

echo "================================================="
echo "ISA Regression — rv32ui"
echo "================================================="

for mem_file in "$MEM_DIR"/rv32ui-p-*.mem; do
    [ -f "$mem_file" ] || continue
    test_name=$(basename "$mem_file" .mem)
    TOTAL=$((TOTAL + 1))

    output=$(cd "$PROJECT_ROOT" && "$VVP_FILE" "+TESTFILE=$mem_file" 2>&1)
    # vvp needs explicit call
    output=$(cd "$PROJECT_ROOT" && vvp "$VVP_FILE" "+TESTFILE=$mem_file" 2>&1)

    if echo "$output" | grep -q "^PASS"; then
        PASSED=$((PASSED + 1))
        printf "  %-35s PASS\n" "$test_name"
    else
        FAILED=$((FAILED + 1))
        fail_msg=$(echo "$output" | grep "^FAIL" | head -1)
        printf "  %-35s FAIL  %s\n" "$test_name" "$fail_msg"
    fi
done

echo ""
echo "================================================="
echo "Total: $TOTAL   Passed: $PASSED   Failed: $FAILED"
if [ "$FAILED" -eq 0 ]; then
    echo "OVERALL STATUS: PASS"
else
    echo "OVERALL STATUS: FAIL"
fi
echo "================================================="

[ "$FAILED" -eq 0 ]
