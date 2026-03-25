# ===========================================================================
# Makefile — JTAG pyUVM Testbench（cocotb + iverilog）
# 用法：
#   make sim       — 运行仿真
#   make waves     — 运行仿真后打开 GTKWave 查看波形
#   make clean     — 清理生成文件
# ===========================================================================

# 仿真器：使用 icarus（iverilog）
SIM            ?= icarus
TOPLEVEL_LANG  ?= verilog

# DUT 和 testbench 顶层 Verilog 文件
VERILOG_SOURCES = ../../rtl/jtag_tap.v tb_top.v

# cocotb 顶层模块名（必须与 tb_top.v 中的 module 名一致）
TOPLEVEL = tb_top

# cocotb 测试模块（不含 .py 后缀）
MODULE = jtag_test

# Python 路径：让 cocotb 能找到所有本地 .py 文件
export PYTHONPATH := $(shell pwd):$(PYTHONPATH)

# 引入 cocotb 标准 Makefile（必须放在最后）
include $(shell cocotb-config --makefiles)/Makefile.sim

# ---------------------------------------------------------------------------
# 额外目标
# ---------------------------------------------------------------------------

# 打开 GTKWave 查看波形
waves: sim
	@if command -v gtkwave &>/dev/null; then \
		gtkwave tb_jtag_pyuvm.vcd & \
	else \
		echo "[waves] 未找到 gtkwave，请手动打开 tb_jtag_pyuvm.vcd"; \
	fi

# 安装 Python 依赖
install-deps:
	pip install -r requirements.txt

.PHONY: waves install-deps
