# Simple RISC-V CPU

这是一个基于 Verilog 实现的基础 RISC-V 32位处理器 (RV32I) 核心。

## 简介

本项目包含一个简易的单周期（或者包含基础状态机）RISC-V RV32I 处理器核心。包含所有基础模块的硬件实现和测试环境。

## 目录结构

```
simple_riscv_cpu/
├── rtl/               # Verilog RTL 源码（CPU 核心模块、存储、外设等）
├── tb/                # Testbench 测试文件（分为单元测试、集成测试、ISA 回归测试）
├── tests/             # RISC-V ISA 兼容性测试和相关内存固件
├── scripts/           # Python 和 Bash 等辅助工具脚本
├── Makefile           # 自动化构建和测试脚本
└── README.md          # 本文档
```

## 前置依赖

请在系统中安装以下工具来进行编译和仿真：

- [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` 和 `vvp`)
- GNU Make

可选（如果要运行交叉编译工具链重新编译 `.mem` 测试固件）：
- [RISC-V GNU Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) (`riscv64-unknown-elf-gcc` 等)

## 快速开始

克隆本仓库及更新测试子模块：

```bash
git clone https://github.com/Brosax/simple_riscv_cpu.git
cd simple_riscv_cpu
git submodule update --init
```

### 运行仿真测试

本仓库使用 `Makefile` 管理所有测试，全部硬件仿真均使用 Icarus Verilog 进行。

```bash
# 清除编译产物
make clean

# 1. 运行所有硬件模块的单元测试 (Unit Tests)
make unit-tests

# (可选) 运行单独某个模块的单元测试，例如 ALU：
make _unit_alu

# 2. 运行整体 CPU 的集成测试 (Integration Tests)
make integration-tests

# 3. 运行 RISC-V ISA 兼容性回归测试
make isa-regression
```

## 硬件模块清单

`rtl/` 目录下包含以下核心模块：

### 核心数据通路与控制
- `riscv_core.v`: 顶层 RISC-V 核心处理器模块
- `pc_register.v`: 程序计数器（Program Counter）
- `control_unit.v`: 主控制单元，负责解析指令
- `alu.v`: 算术逻辑单元（Arithmetic Logic Unit）
- `alu_control_unit.v`: ALU控制单元
- `register_file.v`: 32位通用寄存器堆
- `immediate_generator.v`: 立即数生成器
- `csr_file.v`: 控制与状态寄存器堆（CSRs）

### 存储模块
- `instruction_memory.v`: 指令存储器
- `data_memory.v`: 数据存储器

### 外设与 FPGA 顶层
- `gpio.v`: 通用输入输出端口
- `timer.v`: 硬件定时器
- `uart_tx.v`: 串口发送模块（UART TX）
- `basys3_top.v`: 针对 Basys3 FPGA 开发板的硬件系统顶层集成
