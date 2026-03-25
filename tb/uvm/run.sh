#!/bin/bash
# ============================================================================
# JTAG UVM Testbench 仿真脚本
# 支持 VCS（推荐）和 Xcelium（备选），iverilog 不支持 UVM
# ============================================================================

set -e

DUT_RTL="../../rtl/jtag_tap.v"
TB_TOP="tb_top.sv"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=================================================="
echo " JTAG UVM Testbench"
echo "=================================================="

# ------------------------------------------------------------------
# VCS 仿真（需要 Synopsys VCS 和 UVM 库）
# ------------------------------------------------------------------
run_vcs() {
    echo -e "${GREEN}[VCS] 编译...${NC}"
    vcs -full64 -sverilog -ntb_opts uvm-1.2 \
        +incdir+${VCS_HOME}/etc/uvm-1.2/src \
        ${VCS_HOME}/etc/uvm-1.2/src/uvm_pkg.sv \
        ${DUT_RTL} \
        ${TB_TOP} \
        -timescale=1ns/1ps \
        -l compile.log \
        -o simv

    echo -e "${GREEN}[VCS] 仿真运行...${NC}"
    ./simv +UVM_TESTNAME=jtag_test \
           +UVM_VERBOSITY=UVM_MEDIUM \
           -l sim.log

    echo -e "${GREEN}[VCS] 完成，日志: sim.log${NC}"
}

# ------------------------------------------------------------------
# Xcelium 仿真（需要 Cadence Xcelium 和 UVM 库）
# ------------------------------------------------------------------
run_xcelium() {
    echo -e "${GREEN}[Xcelium] 编译并运行...${NC}"
    xrun -sv -uvm \
         ${DUT_RTL} \
         ${TB_TOP} \
         -timescale 1ns/1ps \
         +UVM_TESTNAME=jtag_test \
         +UVM_VERBOSITY=UVM_MEDIUM \
         -log sim.log

    echo -e "${GREEN}[Xcelium] 完成，日志: sim.log${NC}"
}

# ------------------------------------------------------------------
# Questa/ModelSim 仿真
# ------------------------------------------------------------------
run_questa() {
    echo -e "${GREEN}[Questa] 编译...${NC}"
    vlib work
    vlog -sv -mfcu \
         +incdir+${QUESTA_UVM_HOME}/src \
         ${QUESTA_UVM_HOME}/src/uvm_pkg.sv \
         ${DUT_RTL} \
         ${TB_TOP}

    echo -e "${GREEN}[Questa] 仿真运行...${NC}"
    vsim -batch -do "run -all; quit -f" \
         +UVM_TESTNAME=jtag_test \
         +UVM_VERBOSITY=UVM_MEDIUM \
         tb_top \
         -l sim.log

    echo -e "${GREEN}[Questa] 完成，日志: sim.log${NC}"
}

# ------------------------------------------------------------------
# 主逻辑：根据可用工具选择
# ------------------------------------------------------------------
if   command -v vcs     &>/dev/null; then run_vcs
elif command -v xrun    &>/dev/null; then run_xcelium
elif command -v vsim    &>/dev/null; then run_questa
else
    echo -e "${RED}错误: 未找到支持 UVM 的仿真器（VCS / Xcelium / Questa）${NC}"
    echo ""
    echo "注意: iverilog 不支持 UVM。"
    echo "请安装以下任意一种仿真器："
    echo "  - Synopsys VCS      (需设置 VCS_HOME)"
    echo "  - Cadence Xcelium   (需设置 XCELIUM_HOME)"
    echo "  - Mentor Questa     (需设置 QUESTA_UVM_HOME)"
    exit 1
fi

# ------------------------------------------------------------------
# 查看波形（如果有 GTKWave）
# ------------------------------------------------------------------
if [ -f "tb_jtag_uvm.vcd" ] && command -v gtkwave &>/dev/null; then
    echo -e "${GREEN}打开 GTKWave 查看波形...${NC}"
    gtkwave tb_jtag_uvm.vcd &
fi
