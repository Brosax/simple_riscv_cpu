# Makefile for cocotb JTAG tests
# Usage: cd tb/cocotb && make MODULE=test_idcode
#   Or from root: make cocotb-tests MODULE=test_idcode

SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Detect which testbench to use based on MODULE name
_jtag_tap_modules := test_tap_fsm test_idcode test_bypass
_is_jtag_tap := $(foreach m,$(strip $(MODULE)),$(findstring $(m),$(_jtag_tap_modules)))

RTL_DIR := ../../rtl

# TAP-only tests
VERILOG_SOURCES_TAP = $(RTL_DIR)/jtag_tap.v
TOPLEVEL_TAP = tb_jtag_tap

# Full integration tests (all RTL files)
RTL_ALL = $(RTL_DIR)/alu.v \
          $(RTL_DIR)/alu_control_unit.v \
          $(RTL_DIR)/control_unit.v \
          $(RTL_DIR)/data_memory.v \
          $(RTL_DIR)/gpio.v \
          $(RTL_DIR)/immediate_generator.v \
          $(RTL_DIR)/instruction_memory.v \
          $(RTL_DIR)/jtag_tap.v \
          $(RTL_DIR)/pc_register.v \
          $(RTL_DIR)/register_file.v \
          $(RTL_DIR)/riscv_core.v \
          $(RTL_DIR)/riscv_core_jtag.v \
          $(RTL_DIR)/timer.v

VERILOG_SOURCES_CORE = $(RTL_ALL)
TOPLEVEL_CORE = tb_riscv_core_jtag

# Choose based on MODULE
ifeq ($(strip $(_is_jtag_tap)),)
  VERILOG_SOURCES = $(VERILOG_SOURCES_CORE)
  TOPLEVEL        = $(TOPLEVEL_CORE)
else
  VERILOG_SOURCES = $(VERILOG_SOURCES_TAP)
  TOPLEVEL        = $(TOPLEVEL_TAP)
endif

COCOTB_RESOURCES = .

# Pull in cocotb's standard Makefile (must be last)
include $(shell cocotb-config --makefiles)/Makefile.sim
