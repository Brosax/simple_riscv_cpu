#!/bin/bash

#
# 自动将 riscv-tests 的已编译ELF文件转换为Verilog .hex 格式
#
# 该脚本会遍历指定目录下的 RISC-V 测试ELF文件，并使用 riscv32-unknown-elf-objcopy 工具
# 将它们转换为 Verilog HDL 可读取的 .hex 文件格式。
#
# 用法：
# 1. 确保 riscv32-unknown-elf-objcopy 等 RISC-V 工具链已安装并配置在系统PATH中。
# 2. 在 riscv-tests 仓库中运行 'make'，以生成ELF测试文件。
# 3. 在 riscv-tests 仓库的根目录执行此脚本。
#

# --- 配置 ---
# riscv-tests 的工作目录
TEST_ISA_DIR="test/isa/rv32ui"

# RISC-V GCC 工具链前缀
# 请确保 riscv32-unknown-elf-gcc 等工具已在您的系统PATH中
TOOL_PREFIX="riscv32-unknown-elf-"

# --- 主逻辑 ---
echo "========================================================"
echo "Generating Verilog .hex files from ELF executables..."
echo "Source Directory: ${TEST_ISA_DIR}"
echo "========================================================"

# 检查源目录是否存在
if [ ! -d "$TEST_ISA_DIR" ]; then
    echo "Error: Directory '${TEST_ISA_DIR}' not found."
    echo "Please ensure you have run 'make' inside 'tests/riscv-tests' first."
    exit 1
fi

# 查找所有 rv32ui 和 rv32mi 的测试程序 (ELF文件)
# 这些文件通常没有扩展名，所以我们用 -type f 来查找文件
find "${TEST_ISA_DIR}" \( -name "rv32ui-p-*" -o -name "rv32mi-p-*" \) -type f | while read elf_file; do

    # 从完整路径中提取文件名，例如 "rv32ui-p-add"
    # shellcheck disable=SC2001
    test_name=$(echo "${elf_file}" | sed 's/.*\///')

    # 定义输出的 .hex 文件路径和名称
    hex_file="${elf_file}.hex"

    echo "Converting: ${test_name}  ->  ${test_name}.hex"

    # 执行 objcopy 命令
    "${TOOL_PREFIX}objcopy" -O verilog "${elf_file}" "${hex_file}"

    # 检查命令是否成功
    if [ $? -ne 0 ]; then
        echo "  -> ERROR: Failed to convert ${test_name}"
    fi
done

echo "========================================================"
echo "Hex file generation complete."
echo "Files are located in ${TEST_ISA_DIR}"
echo "========================================================"
