# ============================================================
# simple_riscv_cpu — Test Orchestration Makefile
# ============================================================

IVERILOG  = iverilog
VVP       = vvp
IVFLAGS   = -g2012

RTL_DIR   = rtl
TB_DIR    = tb
MEM_DIR   = tests/isa/mem
SCRIPTS   = scripts
BUILD     = build

RTL_SRC   = $(filter-out $(RTL_DIR)/basys3_top.v $(RTL_DIR)/uart_tx.v, $(wildcard $(RTL_DIR)/*.v))

$(shell mkdir -p $(BUILD))

# ============================================================
# Level 1: Unit Tests
# ============================================================

UNIT_MODULES = alu alu_control_unit alu_sll control_unit data_memory \
               gpio immediate_generator pc_register register_file timer

RTL_alu                 = $(RTL_DIR)/alu.v
RTL_alu_control_unit    = $(RTL_DIR)/alu_control_unit.v
RTL_alu_sll             = $(RTL_DIR)/alu.v
RTL_control_unit        = $(RTL_DIR)/control_unit.v
RTL_data_memory         = $(RTL_DIR)/data_memory.v
RTL_gpio                = $(RTL_DIR)/gpio.v
RTL_immediate_generator = $(RTL_DIR)/immediate_generator.v
RTL_pc_register         = $(RTL_DIR)/pc_register.v
RTL_register_file       = $(RTL_DIR)/register_file.v
RTL_timer               = $(RTL_DIR)/timer.v

.PHONY: unit-tests $(addprefix _unit_,$(UNIT_MODULES))

unit-tests: $(addprefix _unit_,$(UNIT_MODULES))
	@echo ""
	@echo "=== All unit tests completed ==="

$(addprefix _unit_,$(UNIT_MODULES)): _unit_%:
	@echo "--- Unit test: $* ---"
	@$(IVERILOG) $(IVFLAGS) -o $(BUILD)/tb_$*.vvp \
	    $(TB_DIR)/unit/tb_$*.v $(RTL_$*)
	@$(VVP) $(BUILD)/tb_$*.vvp

# ============================================================
# Level 2: Integration Tests
# ============================================================

.PHONY: integration-tests

integration-tests: $(BUILD)/tb_rv32i_inline.vvp
	@echo "--- Integration test: rv32i_inline ---"
	@$(VVP) $<
	@echo ""
	@echo "=== Integration test completed ==="

$(BUILD)/tb_rv32i_inline.vvp: $(TB_DIR)/integration/tb_rv32i_inline.v $(RTL_SRC)
	@$(IVERILOG) $(IVFLAGS) -o $@ $^

# ============================================================
# Level 4: Cocotb JTAG Tests
# ============================================================

COCOTB_DIR   = tb/cocotb
SIM          ?= icarus
RTL_DIR      := $(abspath $(CURDIR)/rtl)

# TAP-only modules (standalone JTAG TAP test)
COCOTB_TAP_MODULES = test_tap_fsm test_idcode test_bypass

# Detect which sources to use
_is_tap_test = $(foreach m,$(MODULE),$(findstring $(m),$(COCOTB_TAP_MODULES)))

RTL_TAP = $(RTL_DIR)/jtag_tap.v
RTL_CORE = $(RTL_DIR)/alu.v \
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

TOPLEVEL_TAP  = tb_jtag_tap
TOPLEVEL_CORE = tb_riscv_core_jtag

# Choose based on module
ifeq ($(strip $(_is_tap_test)),)
  VERILOG_SOURCES = $(RTL_CORE)
  TOPLEVEL        = $(TOPLEVEL_CORE)
else
  VERILOG_SOURCES = $(RTL_TAP)
  TOPLEVEL        = $(TOPLEVEL_TAP)
endif

.PHONY: cocotb-tests
cocotb-tests: export MODULE ?= test_idcode
cocotb-tests:
	@echo "--- Running cocotb: $(MODULE) on $(TOPLEVEL) ---"
	@cd $(COCOTB_DIR) && rm -rf __pycache__ sim_build results.xml *.vcd && \
		SIM=$(SIM) TOPLEVEL=$(TOPLEVEL) \
		VERILOG_SOURCES="$(VERILOG_SOURCES)" \
		$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim clean run

# Convenience targets
cocotb-tap-fsm:
	@$(MAKE) cocotb-tests MODULE=test_tap_fsm && \
	$(MAKE) cocotb-tests MODULE=test_idcode && \
	$(MAKE) cocotb-tests MODULE=test_bypass

cocotb-debug:
	@$(MAKE) cocotb-tests MODULE=test_debug_regs && \
	$(MAKE) cocotb-tests MODULE=test_debug_mem && \
	$(MAKE) cocotb-tests MODULE=test_integration

cocotb-all:
	@$(MAKE) cocotb-tests MODULE=test_tap_fsm && \
	$(MAKE) cocotb-tests MODULE=test_idcode && \
	$(MAKE) cocotb-tests MODULE=test_bypass && \
	$(MAKE) cocotb-tests MODULE=test_debug_regs && \
	$(MAKE) cocotb-tests MODULE=test_debug_mem && \
	$(MAKE) cocotb-tests MODULE=test_integration

# ============================================================
# Level 3: ISA Regression Tests
# ============================================================

$(BUILD)/tb_isa_test.vvp: $(TB_DIR)/isa/tb_isa_test.v $(RTL_SRC)
	@$(IVERILOG) $(IVFLAGS) -o $@ $^

.PHONY: gen-mem
gen-mem:
	@bash $(SCRIPTS)/generate_mem_files.sh

# Run a single ISA test: make isa-test TEST=rv32ui-p-add
.PHONY: isa-test
isa-test: $(BUILD)/tb_isa_test.vvp
	@$(VVP) $< +TESTFILE=$(MEM_DIR)/$(TEST).mem

.PHONY: isa-regression
isa-regression: $(BUILD)/tb_isa_test.vvp
	@bash $(SCRIPTS)/run_isa_regression.sh

# ============================================================
# Meta targets
# ============================================================

.PHONY: test all clean

test: unit-tests integration-tests isa-regression

all: test

clean:
	@rm -rf $(BUILD)
	@rm -f *.vcd signature.log inst.mem test_program.txt
	@echo "Cleaned build artifacts."
