#!/bin/bash
# Converts all pre-compiled .bin test files to $readmemh-compatible .mem files.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GEN_DIR="$PROJECT_ROOT/tests/isa/generated"
MEM_DIR="$PROJECT_ROOT/tests/isa/mem"
BIN_TO_MEM="$SCRIPT_DIR/bin_to_mem.py"

mkdir -p "$MEM_DIR"

count=0
for bin_file in "$GEN_DIR"/*.bin; do
    [ -f "$bin_file" ] || continue
    test_name=$(basename "$bin_file" .bin)
    python3 "$BIN_TO_MEM" "$bin_file" "$MEM_DIR/${test_name}.mem"
    count=$((count + 1))
done

echo "Generated $count .mem files in $MEM_DIR"
