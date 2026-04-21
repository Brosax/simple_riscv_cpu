import sys

with open('rtl/riscv_core.v', 'r') as f:
    content = f.read()

# Add ext_interrupt
content = content.replace(
    'output wire timer_interrupt,',
    'output wire timer_interrupt,\n\tinput wire ext_interrupt,'
)

# Add localparam OPCODE_SYSTEM
content = content.replace(
    'localparam OPCODE_AUIPC = 7\'b0010111;',
    'localparam OPCODE_AUIPC = 7\'b0010111;\n\tlocalparam OPCODE_SYSTEM = 7\'b1110011;'
)

# SYSTEM instruction decoding
sys_decoding = """
	// System instruction decode
	wire is_system = (opcode == OPCODE_SYSTEM);
	wire is_csr    = is_system && (funct3 != 3'b000);
	wire is_mret   = is_system && (funct3 == 3'b000) && (instruction[31:20] == 12'h302);
	wire is_ecall  = is_system && (funct3 == 3'b000) && (instruction[31:20] == 12'h000);
	wire is_ebreak = is_system && (funct3 == 3'b000) && (instruction[31:20] == 12'h001);

	// CSR Data path
	wire [31:0] csr_rdata;
	reg  [31:0] csr_wdata;
	always @(*) begin
		case (funct3)
			3'b001: csr_wdata = reg_read_data1; // CSRRW
			3'b010: csr_wdata = csr_rdata | reg_read_data1; // CSRRS
			3'b011: csr_wdata = csr_rdata & ~reg_read_data1; // CSRRC
			3'b101: csr_wdata = {27'b0, rs1}; // CSRRWI (rs1 field is zimm)
			3'b110: csr_wdata = csr_rdata | {27'b0, rs1}; // CSRRSI
			3'b111: csr_wdata = csr_rdata & ~{27'b0, rs1}; // CSRRCI
			default: csr_wdata = 32'b0;
		endcase
	end

	wire csr_we = is_csr && instruction_done && (funct3[1:0] != 2'b00 || rs1 != 5'b0); // don't write if rs1=0 for RS/RC

	// Exception / Interrupt Logic
	wire timer_irq_internal = timer_interrupt_internal;
	wire [31:0] mtvec_out;
	wire [31:0] mepc_out;
	wire mstatus_mie;
	wire mie_mtie;
	wire mie_meie;
	wire mip_mtip;
	wire mip_meip;

	wire interrupt_pending = mstatus_mie && ( (mie_mtie && mip_mtip) || (mie_meie && mip_meip) );
	
	// We take a trap when we are at S_FETCH (before executing a new instruction) and an interrupt is pending,
	// OR when we finish executing an ECALL/EBREAK
	wire trap_trigger = (cpu_state == S_FETCH && interrupt_pending) || (instruction_done && (is_ecall || is_ebreak));
	wire mret_trigger = instruction_done && is_mret;
	
	wire [31:0] trap_pc = (cpu_state == S_FETCH && interrupt_pending) ? pc_current : pc_current; // for ecall it's pc_current
	wire [31:0] trap_cause = (cpu_state == S_FETCH && interrupt_pending && mie_meie && mip_meip) ? 32'h8000000B : // Machine external int
	                         (cpu_state == S_FETCH && interrupt_pending && mie_mtie && mip_mtip) ? 32'h80000007 : // Machine timer int
	                         is_ecall ? 32'd11 : // Environment call from M-mode
	                         is_ebreak ? 32'd3 : // Breakpoint
	                         32'd0;

	// Overwrite CPU stall so we don't fetch/exec during a trap jump
	wire real_pc_stall  = stall || (!instruction_done && !trap_trigger); // modify later in the file
"""
content = content.replace('wire funct7_bit5 = instruction[30];', 'wire funct7_bit5 = instruction[30];\n' + sys_decoding)

# CSR module instantiation
csr_inst = """
	// 11. CSR File
	csr_file csr_inst(
		.clk(clk),
		.rst(rst),
		.csr_addr(instruction[31:20]),
		.csr_wdata(csr_wdata),
		.csr_we(csr_we),
		.csr_rdata(csr_rdata),
		.timer_irq(timer_irq_internal),
		.ext_irq(ext_interrupt),
		.trap_trigger(trap_trigger),
		.trap_pc(trap_pc),
		.trap_cause(trap_cause),
		.mret_trigger(mret_trigger),
		.mtvec_out(mtvec_out),
		.mepc_out(mepc_out),
		.mstatus_mie(mstatus_mie),
		.mie_mtie(mie_mtie),
		.mie_meie(mie_meie),
		.mip_mtip(mip_mtip),
		.mip_meip(mip_meip)
	);
"""
content = content.replace('// 10. GPIO', csr_inst + '\n\t// 10. GPIO')

# Timer interrupt wiring
content = content.replace('wire timer_read_data;', 'wire timer_read_data;\n\twire timer_interrupt_internal;')
content = content.replace('.interrupt(timer_interrupt)', '.interrupt(timer_interrupt_internal)')
content = content.replace('	assign debug_stall_status = cpu_stall;', '	assign timer_interrupt = timer_interrupt_internal;\n	assign debug_stall_status = cpu_stall;')

# FSM state machine modifications for trap
fsm_logic = """
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cpu_state <= S_FETCH;
        end else if (!cpu_stall) begin
            if (trap_trigger || mret_trigger) begin
                cpu_state <= S_FETCH; // reset to fetch after trap/mret
            end else begin
                case (cpu_state)
                    S_FETCH:  if (!interrupt_pending) cpu_state <= S_EXEC;
                    S_EXEC:   if (opcode == OPCODE_I_TYPE_LOAD) 
                                  cpu_state <= S_MEM_WB;
                              else 
                                  cpu_state <= S_FETCH;
                    S_MEM_WB: cpu_state <= S_FETCH;
                    default:  cpu_state <= S_FETCH;
                endcase
            end
        end
    end
"""
import re
content = re.sub(r'always @\(posedge clk or posedge rst\) begin\s*if \(rst\) begin\s*cpu_state <= S_FETCH;\s*end else if \(\!cpu_stall\) begin.*?(?=\s*// 指令完成标志)', fsm_logic, content, flags=re.DOTALL | re.MULTILINE)

content = content.replace('wire real_pc_stall  = stall || !instruction_done; // 指令没完成前，死死冻结 PC', 'wire real_pc_stall  = stall || (!instruction_done && !trap_trigger && !mret_trigger); //  trap/mret 强制放行 PC 更新')
content = content.replace('wire real_reg_write = reg_write && instruction_done;', 'wire real_reg_write = reg_write && instruction_done && !is_ecall && !is_ebreak && !is_mret; // SYSTEM 指令不一定写寄存器')

content = content.replace('assign pc_next = (jump && opcode == OPCODE_JAL) ? pc_target_imm :', 'assign pc_next = trap_trigger ? mtvec_out : mret_trigger ? mepc_out : (jump && opcode == OPCODE_JAL) ? pc_target_imm :')

content = content.replace('assign write_back_data = jump ? pc_plus_4 : (mem_to_reg ? mem_read_data : alu_result);', 'assign write_back_data = is_csr ? csr_rdata : jump ? pc_plus_4 : (mem_to_reg ? mem_read_data : alu_result);')

with open('rtl/riscv_core.v', 'w') as f:
    f.write(content)
