#!/bin/bash

# --- Configuration ---
HEX_DIR="test/isa/hex"

echo "========================================================"
echo "Preparing Verilog .hex files..."
echo "Target Directory: ${HEX_DIR}"
echo "========================================================"

# Find all .hex files and remove the address specifier
find "${HEX_DIR}" -name "*.hex" -print0 | while IFS= read -r -d $'\0' hex_file; do
    echo "Processing: ${hex_file}"
    sed -i '/^@/d' "${hex_file}"
done

echo "========================================================"
echo "Hex file preparation complete."
echo "========================================================"
